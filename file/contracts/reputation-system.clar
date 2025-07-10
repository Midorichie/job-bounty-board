;; Reputation System Contract
;; Standalone contract for managing user reputation across the platform

;; Error constants
(define-constant err-not-authorized (err u200))
(define-constant err-user-not-found (err u201))
(define-constant err-invalid-rating (err u202))
(define-constant err-already-reviewed (err u203))

;; Constants
(define-constant max-rating u100)
(define-constant min-rating u0)
(define-constant default-rating u50)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Authorized contracts that can update reputation
(define-map authorized-contracts
  ((contract principal))
  ((authorized bool))
)

;; Detailed user reputation data
(define-map user-profiles
  ((user principal))
  (
    total-tasks-posted uint
    total-tasks-completed uint
    total-earnings uint
    total-spent uint
    disputes-won uint
    disputes-lost uint
    overall-rating uint
    review-count uint
    last-active uint
    profile-created uint
    badges (list 10 (string-ascii 20))
  )
)

;; Peer reviews between users
(define-map peer-reviews
  ((reviewer principal) (reviewee principal) (task-id uint))
  (
    rating uint
    comment (string-ascii 200)
    created-at uint
  )
)

;; Badge system for achievements
(define-map available-badges
  ((badge-name (string-ascii 20)))
  (
    description (string-ascii 100)
    requirement uint
    active bool
  )
)

;; User achievement tracking
(define-map user-achievements
  ((user principal) (badge-name (string-ascii 20)))
  (
    earned-at uint
    task-id (optional uint)
  )
)

;; Initialize badge system - Fixed version
(define-private (init-badges)
  (begin
    (map-set available-badges 
      ((badge-name "rookie")) 
      ((description "Complete your first task") (requirement u1) (active true)))
    (map-set available-badges 
      ((badge-name "reliable")) 
      ((description "Complete 10 tasks") (requirement u10) (active true)))
    (map-set available-badges 
      ((badge-name "expert")) 
      ((description "Complete 50 tasks") (requirement u50) (active true)))
    (map-set available-badges 
      ((badge-name "top-earner")) 
      ((description "Earn 100 STX") (requirement u100000000) (active true)))
    (map-set available-badges 
      ((badge-name "dispute-winner")) 
      ((description "Win 5 disputes") (requirement u5) (active true)))
    (map-set available-badges 
      ((badge-name "highly-rated")) 
      ((description "Maintain 90+ rating with 10+ reviews") (requirement u90) (active true)))
    true
  )
)

;; Initialize user profile
(define-private (init-user-profile (user principal))
  (map-set user-profiles
    ((user user))
    {
      total-tasks-posted: u0,
      total-tasks-completed: u0,
      total-earnings: u0,
      total-spent: u0,
      disputes-won: u0,
      disputes-lost: u0,
      overall-rating: default-rating,
      review-count: u0,
      last-active: block-height,
      profile-created: block-height,
      badges: (list)
    }
  )
)

;; Get or create user profile
(define-private (get-or-create-profile (user principal))
  (match (map-get user-profiles ((user user)))
    profile profile
    (begin
      (init-user-profile user)
      (unwrap-panic (map-get user-profiles ((user user))))
    )
  )
)

;; Update user reputation (only authorized contracts)
(define-public (update-reputation 
  (user principal) 
  (task-completed bool)
  (earnings uint)
  (spent uint)
  (dispute-won bool)
  (dispute-lost bool)
)
  (let (
    (is-authorized (default-to false (get authorized (map-get authorized-contracts ((contract tx-sender))))))
    (profile (get-or-create-profile user))
  )
    (asserts! is-authorized err-not-authorized)
    
    (let (
      (new-completed (if task-completed (+ (get total-tasks-completed profile) u1) (get total-tasks-completed profile)))
      (new-earnings (+ (get total-earnings profile) earnings))
      (new-spent (+ (get total-spent profile) spent))
      (new-disputes-won (if dispute-won (+ (get disputes-won profile) u1) (get disputes-won profile)))
      (new-disputes-lost (if dispute-lost (+ (get disputes-lost profile) u1) (get disputes-lost profile)))
    )
      (begin
        (map-set user-profiles
          ((user user))
          (merge profile {
            total-tasks-completed: new-completed,
            total-earnings: new-earnings,
            total-spent: new-spent,
            disputes-won: new-disputes-won,
            disputes-lost: new-disputes-lost,
            last-active: block-height
          })
        )
        ;; Check and award badges
        (try! (check-and-award-badges user))
        (ok true)
      )
    )
  )
)

;; Update task posting count
(define-public (update-task-posted (user principal))
  (let (
    (is-authorized (default-to false (get authorized (map-get authorized-contracts ((contract tx-sender))))))
    (profile (get-or-create-profile user))
  )
    (asserts! is-authorized err-not-authorized)
    
    (begin
      (map-set user-profiles
        ((user user))
        (merge profile {
          total-tasks-posted: (+ (get total-tasks-posted profile) u1),
          last-active: block-height
        })
      )
      (ok true)
    )
  )
)

;; Add peer review
(define-public (add-peer-review 
  (reviewee principal) 
  (task-id uint)
  (rating uint) 
  (comment (string-ascii 200))
)
  (let (
    (existing-review (map-get peer-reviews ((reviewer tx-sender) (reviewee reviewee) (task-id task-id))))
    (reviewee-profile (get-or-create-profile reviewee))
  )
    (asserts! (is-none existing-review) err-already-reviewed)
    (asserts! (and (>= rating min-rating) (<= rating max-rating)) err-invalid-rating)
    (asserts! (not (is-eq tx-sender reviewee)) err-not-authorized)
    
    (begin
      ;; Add the review
      (map-set peer-reviews
        ((reviewer tx-sender) (reviewee reviewee) (task-id task-id))
        {
          rating: rating,
          comment: comment,
          created-at: block-height
        }
      )
      ;; Update reviewee's overall rating
      (try! (update-overall-rating reviewee rating))
      (ok true)
    )
  )
)

;; Update overall rating based on new review
(define-private (update-overall-rating (user principal) (new-rating uint))
  (let (
    (profile (get-or-create-profile user))
    (current-rating (get overall-rating profile))
    (review-count (get review-count profile))
    (total-rating-points (* current-rating review-count))
    (new-total-points (+ total-rating-points new-rating))
    (new-review-count (+ review-count u1))
    (new-overall-rating (/ new-total-points new-review-count))
  )
    (map-set user-profiles
      ((user user))
      (merge profile {
        overall-rating: new-overall-rating,
        review-count: new-review-count
      })
    )
    (ok true)
  )
)

;; Check and award badges
(define-private (check-and-award-badges (user principal))
  (let ((profile (get-or-create-profile user)))
    (begin
      ;; Check rookie badge
      (if (and (>= (get total-tasks-completed profile) u1) 
               (is-none (map-get user-achievements ((user user) (badge-name "rookie")))))
        (try! (award-badge user "rookie" none))
        (ok true)
      )
      ;; Check reliable badge
      (if (and (>= (get total-tasks-completed profile) u10) 
               (is-none (map-get user-achievements ((user user) (badge-name "reliable")))))
        (try! (award-badge user "reliable" none))
        (ok true)
      )
      ;; Check expert badge
      (if (and (>= (get total-tasks-completed profile) u50) 
               (is-none (map-get user-achievements ((user user) (badge-name "expert")))))
        (try! (award-badge user "expert" none))
        (ok true)
      )
      ;; Check top-earner badge
      (if (and (>= (get total-earnings profile) u100000000) 
               (is-none (map-get user-achievements ((user user) (badge-name "top-earner")))))
        (try! (award-badge user "top-earner" none))
        (ok true)
      )
      ;; Check dispute-winner badge
      (if (and (>= (get disputes-won profile) u5) 
               (is-none (map-get user-achievements ((user user) (badge-name "dispute-winner")))))
        (try! (award-badge user "dispute-winner" none))
        (ok true)
      )
      ;; Check highly-rated badge
      (if (and (>= (get overall-rating profile) u90) 
               (>= (get review-count profile) u10)
               (is-none (map-get user-achievements ((user user) (badge-name "highly-rated")))))
        (try! (award-badge user "highly-rated" none))
        (ok true)
      )
    )
  )
)

;; Award badge to user
(define-private (award-badge (user principal) (badge-name (string-ascii 20)) (task-id (optional uint)))
  (let ((profile (get-or-create-profile user)))
    (begin
      (map-set user-achievements
        ((user user) (badge-name badge-name))
        {
          earned-at: block-height,
          task-id: task-id
        }
      )
      ;; Add badge to user's badge list if not already present
      (let ((current-badges (get badges profile)))
        (if (is-none (index-of current-badges badge-name))
          (map-set user-profiles
            ((user user))
            (merge profile {
              badges: (unwrap-panic (as-max-len? (append current-badges badge-name) u10))
            })
          )
          false
        )
      )
      (ok true)
    )
  )
)

;; Admin functions
(define-public (authorize-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (map-set authorized-contracts ((contract contract)) ((authorized true)))
    (ok true)
  )
)

(define-public (deauthorize-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (map-set authorized-contracts ((contract contract)) ((authorized false)))
    (ok true)
  )
)

(define-public (add-badge (badge-name (string-ascii 20)) (description (string-ascii 100)) (requirement uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (map-set available-badges
      ((badge-name badge-name))
      {
        description: description,
        requirement: requirement,
        active: true
      }
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-user-profile (user principal))
  (map-get user-profiles ((user user)))
)

(define-read-only (get-peer-review (reviewer principal) (reviewee principal) (task-id uint))
  (map-get peer-reviews ((reviewer reviewer) (reviewee reviewee) (task-id task-id)))
)

(define-read-only (get-user-badges (user principal))
  (match (map-get user-profiles ((user user)))
    profile (get badges profile)
    (list)
  )
)

(define-read-only (get-badge-info (badge-name (string-ascii 20)))
  (map-get available-badges ((badge-name badge-name)))
)

(define-read-only (get-user-achievement (user principal) (badge-name (string-ascii 20)))
  (map-get user-achievements ((user user) (badge-name badge-name)))
)

(define-read-only (is-contract-authorized (contract principal))
  (default-to false (get authorized (map-get authorized-contracts ((contract contract)))))
)

(define-read-only (get-user-rating (user principal))
  (match (map-get user-profiles ((user user)))
    profile (get overall-rating profile)
    default-rating
  )
)

(define-read-only (get-user-stats (user principal))
  (match (map-get user-profiles ((user user)))
    profile {
      tasks-completed: (get total-tasks-completed profile),
      tasks-posted: (get total-tasks-posted profile),
      earnings: (get total-earnings profile),
      spent: (get total-spent profile),
      rating: (get overall-rating profile),
      review-count: (get review-count profile),
      badges: (get badges profile)
    }
    {
      tasks-completed: u0,
      tasks-posted: u0,
      earnings: u0,
      spent: u0,
      rating: default-rating,
      review-count: u0,
      badges: (list)
    }
  )
)

;; Initialize the contract
(init-badges)
