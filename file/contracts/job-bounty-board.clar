;; Job Bounty Board Smart Contract

(define-constant err-task-not-found (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-already-submitted (err u102))
(define-constant err-task-already-approved (err u103))

(define-data-var task-id-counter uint u0)

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
  )
)

(define-public (post-task (title (string-ascii 50)) (description (string-ascii 200)) (bounty uint))
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
        proof: none
      }
    )
    (ok (var-get task-id-counter))
  )
)

(define-public (submit-task (id uint) (proof (string-ascii 200)))
  (let ((maybe-task (map-get tasks ((id id)))))
    (if (is-some maybe-task)
        (let ((task (unwrap maybe-task err-task-not-found)))
          (if (is-some (get worker task))
              err-already-submitted
              (begin
                (map-set tasks
                  ((id id))
                  (merge task {
                    worker: (some tx-sender),
                    proof: (some proof)
                  })
                )
                (ok true)
              )
          )
        )
        err-task-not-found
    )
  )
)

(define-public (approve-task (id uint))
  (let ((maybe-task (map-get tasks ((id id)))))
    (if (is-some maybe-task)
        (let ((task (unwrap maybe-task err-task-not-found)))
          (if (is-eq (get poster task) tx-sender)
              (if (get is-completed task)
                  err-task-already-approved
                  (let (
                          (maybe-worker (get worker task))
                          (recipient (unwrap-panic maybe-worker))
                          (amount (get bounty task))
                      )
                    (begin
                      (stx-transfer? amount tx-sender recipient)
                      (map-set tasks ((id id)) (merge task { is-completed: true }))
                      (ok true)
                    )
                  )
              )
              err-not-authorized
          )
        )
        err-task-not-found
    )
  )
)
