;; Enhanced Job Bounty Board Smart Contract
;; Fixes bugs, adds security features, and new functionality

;; Error constants
(define-constant err-task-not-found (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-already-submitted (err u102))
(define-constant err-task-already-approved (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-no-worker-assigned (err u105))
(define-constant err-task-expired (err u106))
(define-constant err-invalid-bounty (err u107))
(define-constant err-task-disputed (err u108))
(define-constant err-not-worker (err u109))
(define-constant err-dispute-deadline-passed (err u110))

;; Constants
(define-constant min-bounty u1000000) ;; 1 STX minimum
(define-constant dispute-period u144) ;; 144 blocks (~24 hours)
(define-constant max-task-duration u4320) ;; 4320 blocks (~30 days)

;; Data variables
(define-data-var task-id-counter uint u0)
(define-data-var contract-fee-percentage uint u5) ;; 5% fee
(define-data-var contract-owner principal tx-sender)
(define-data-var total-fees-collected uint u0)

;; Enhanced task structure
(define-map tasks
  ((id uint))
  (
    title (string-ascii 50)
    description (string-ascii 200)
    poster principal
    bounty uint
    is-completed bool
    worker (optional principal)
    proof (optional (string-ascii 200))
    created-at uint
    deadline uint
    dispute-deadline (optional uint)
    is-disputed bool
    category (string-ascii 20)
  )
)

;; User reputation system
(define-map user-reputation
  ((user principal))
  (
    completed-tasks uint
    total-earnings uint
    disputes-won uint
    disputes-lost uint
    rating uint ;; Out of 100
  )
)

;; Task categories for better organization
(define-map task-categories
  ((category (string-ascii 20)))
  ((active bool))
)

;; Dispute tracking
(define-map task-disputes
  ((task-id uint))
  (
    disputant principal
    reason (string-ascii 200)
    created-at uint
    resolved bool
  )
)

;; Initialize default categories - Fixed version
(define-private (init-categories)
  (begin
    (map-set task-categories ((category "development")) ((active true)))
    (map-set task-categories ((category "design")) ((active true)))
    (map-set task-categories ((category "writing")) ((active true)))
    (map-set task-categories ((category "marketing")) ((active true)))
    (map-set task-categories ((category "research")) ((active true)))
    (map-set task-categories ((category "other")) ((active true)))
    true
  )
)

;; Enhanced post-task function with validation and categories
(define-public (post-task 
  (title (string-ascii 50)) 
  (description (string-ascii 200)) 
  (bounty uint)
  (deadline uint)
  (category (string-ascii 20))
)
  (let (
    (category-exists (default-to false (get active (map-get task-categories ((category category))))))
    (current-balance (stx-get-balance tx-sender))
    (task-duration (- deadline block-height))
  )
    (asserts! (>= bounty min-bounty) err-invalid-bounty)
    (asserts! (>= current-balance bounty) err-insufficient-balance)
    (asserts! category-exists err-task-not-found)
    (asserts! (<= task-duration max-task-duration) err-task-expired)
    (asserts! (> deadline block-height) err-task-expired)
    
    (begin
      (var-set task-id-counter (+ (var-get task-id-counter) u1))
      (map-set tasks
        ((id (var-get task-id-counter)))
        {
          title: title,
          description: description,
          poster: tx-sender,
          bounty: bounty,
          is-completed: false,
          worker: none,
          proof: none,
          created-at: block-height,
          deadline: deadline,
          dispute-deadline: none,
          is-disputed: false,
          category: category
        }
      )
      ;; Escrow the bounty amount
      (try! (stx-transfer? bounty tx-sender (as-contract tx-sender)))
      (ok (var-get task-id-counter))
    )
  )
)

;; Enhanced submit-task with deadline check
(define-public (submit-task (id uint) (proof (string-ascii 200)))
  (let ((maybe-task (map-get tasks ((id id)))))
    (asserts! (is-some maybe-task) err-task-not-found)
    (let ((task (unwrap-panic maybe-task)))
      (asserts! (< block-height (get deadline task)) err-task-expired)
      (asserts! (is-none (get worker task)) err-already-submitted)
      (asserts! (not (get is-completed task)) err-task-already-approved)
      (asserts! (not (get is-disputed task)) err-task-disputed)
      
      (begin
        (map-set tasks
          ((id id))
          (merge task {
            worker: (some tx-sender),
            proof: (some proof),
            dispute-deadline: (some (+ block-height dispute-period))
          })
        )
        (ok true)
      )
    )
  )
)

;; Enhanced approve-task with fee collection and reputation update
(define-public (approve-task (id uint))
  (let ((maybe-task (map-get tasks ((id id)))))
    (asserts! (is-some maybe-task) err-task-not-found)
    (let ((task (unwrap-panic maybe-task)))
      (asserts! (is-eq (get poster task) tx-sender) err-not-authorized)
      (asserts! (not (get is-completed task)) err-task-already-approved)
      (asserts! (is-some (get worker task)) err-no-worker-assigned)
      (asserts! (not (get is-disputed task)) err-task-disputed)
      
      (let (
        (worker (unwrap-panic (get worker task)))
        (bounty-amount (get bounty task))
        (fee-amount (/ (* bounty-amount (var-get contract-fee-percentage)) u100))
        (worker-payment (- bounty-amount fee-amount))
      )
        (begin
          ;; Transfer payment to worker
          (try! (as-contract (stx-transfer? worker-payment tx-sender worker)))
          ;; Collect fee for contract
          (try! (as-contract (stx-transfer? fee-amount tx-sender (var-get contract-owner))))
          ;; Update task status
          (map-set tasks ((id id)) (merge task { is-completed: true }))
          ;; Update worker reputation
          (update-user-reputation worker bounty-amount true)
          ;; Update fee tracking
          (var-set total-fees-collected (+ (var-get total-fees-collected) fee-amount))
          (ok true)
        )
      )
    )
  )
)

;; New function: Cancel task (only by poster, only if no worker assigned)
(define-public (cancel-task (id uint))
  (let ((maybe-task (map-get tasks ((id id)))))
    (asserts! (is-some maybe-task) err-task-not-found)
    (let ((task (unwrap-panic maybe-task)))
      (asserts! (is-eq (get poster task) tx-sender) err-not-authorized)
      (asserts! (is-none (get worker task)) err-already-submitted)
      (asserts! (not (get is-completed task)) err-task-already-approved)
      
      (begin
        ;; Return escrowed funds to poster
        (try! (as-contract (stx-transfer? (get bounty task) tx-sender (get poster task))))
        ;; Remove task (by setting bounty to 0 as deletion marker)
        (map-set tasks ((id id)) (merge task { bounty: u0 }))
        (ok true)
      )
    )
  )
)

;; New function: Dispute task (by poster during dispute period)
(define-public (dispute-task (id uint) (reason (string-ascii 200)))
  (let ((maybe-task (map-get tasks ((id id)))))
    (asserts! (is-some maybe-task) err-task-not-found)
    (let ((task (unwrap-panic maybe-task)))
      (asserts! (is-eq (get poster task) tx-sender) err-not-authorized)
      (asserts! (is-some (get worker task)) err-no-worker-assigned)
      (asserts! (not (get is-completed task)) err-task-already-approved)
      (asserts! (not (get is-disputed task)) err-task-disputed)
      
      (let ((dispute-deadline (unwrap! (get dispute-deadline task) err-dispute-deadline-passed)))
        (asserts! (< block-height dispute-deadline) err-dispute-deadline-passed)
        
        (begin
          ;; Mark task as disputed
          (map-set tasks ((id id)) (merge task { is-disputed: true }))
          ;; Record dispute details
          (map-set task-disputes
            ((task-id id))
            {
              disputant: tx-sender,
              reason: reason,
              created-at: block-height,
              resolved: false
            }
          )
          (ok true)
        )
      )
    )
  )
)

;; New function: Resolve dispute (contract owner only)
(define-public (resolve-dispute (id uint) (award-to-worker bool))
  (let ((maybe-task (map-get tasks ((id id)))))
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (asserts! (is-some maybe-task) err-task-not-found)
    (let ((task (unwrap-panic maybe-task)))
      (asserts! (get is-disputed task) err-task-not-found)
      (asserts! (is-some (get worker task)) err-no-worker-assigned)
      
      (let (
        (worker (unwrap-panic (get worker task)))
        (poster (get poster task))
        (bounty-amount (get bounty task))
        (fee-amount (/ (* bounty-amount (var-get contract-fee-percentage)) u100))
        (net-amount (- bounty-amount fee-amount))
      )
        (begin
          ;; Award funds based on resolution
          (if award-to-worker
            (begin
              (try! (as-contract (stx-transfer? net-amount tx-sender worker)))
              (update-user-reputation worker bounty-amount true)
            )
            (try! (as-contract (stx-transfer? net-amount tx-sender poster)))
          )
          ;; Collect fee regardless
          (try! (as-contract (stx-transfer? fee-amount tx-sender (var-get contract-owner))))
          ;; Update task and dispute status
          (map-set tasks ((id id)) (merge task { is-completed: award-to-worker }))
          (map-set task-disputes ((task-id id)) 
            (merge (unwrap-panic (map-get task-disputes ((task-id id)))) { resolved: true }))
          ;; Update reputation
          (if award-to-worker
            (update-user-reputation worker bounty-amount true)
            (update-user-reputation worker u0 false)
          )
          (ok true)
        )
      )
    )
  )
)

;; Helper function to update user reputation
(define-private (update-user-reputation (user principal) (earnings uint) (success bool))
  (let (
    (current-rep (default-to 
      { completed-tasks: u0, total-earnings: u0, disputes-won: u0, disputes-lost: u0, rating: u50 }
      (map-get user-reputation ((user user)))
    ))
  )
    (map-set user-reputation
      ((user user))
      (if success
        (merge current-rep {
          completed-tasks: (+ (get completed-tasks current-rep) u1),
          total-earnings: (+ (get total-earnings current-rep) earnings),
          rating: (min u100 (+ (get rating current-rep) u5))
        })
        (merge current-rep {
          disputes-lost: (+ (get disputes-lost current-rep) u1),
          rating: (max u0 (- (get rating current-rep) u10))
        })
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-task (id uint))
  (map-get tasks ((id id)))
)

(define-read-only (get-user-reputation (user principal))
  (map-get user-reputation ((user user)))
)

(define-read-only (get-task-count)
  (var-get task-id-counter)
)

(define-read-only (get-contract-stats)
  {
    total-tasks: (var-get task-id-counter),
    total-fees-collected: (var-get total-fees-collected),
    contract-fee-percentage: (var-get contract-fee-percentage)
  }
)

(define-read-only (get-dispute-info (task-id uint))
  (map-get task-disputes ((task-id task-id)))
)

;; Contract owner functions
(define-public (set-contract-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (asserts! (<= new-fee u10) err-invalid-bounty) ;; Max 10% fee
    (var-set contract-fee-percentage new-fee)
    (ok true)
  )
)

(define-public (add-task-category (category (string-ascii 20)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-not-authorized)
    (map-set task-categories ((category category)) ((active true)))
    (ok true)
  )
)

;; Initialize categories on deployment
(init-categories)
