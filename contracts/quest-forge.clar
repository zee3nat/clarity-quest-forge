;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u404))
(define-constant err-unauthorized (err u401))
(define-constant err-invalid-level (err u402))

;; Data Variables
(define-map characters principal
  {
    level: uint,
    experience: uint,
    quests-completed: uint
  }
)

(define-map quests uint
  {
    creator: principal,
    title: (string-utf8 100),
    difficulty: uint,
    experience-reward: uint,
    completed: bool
  }
)

(define-data-var quest-counter uint u0)

;; Character Management
(define-public (initialize-character)
  (begin
    (map-set characters tx-sender
      {
        level: u1,
        experience: u0,
        quests-completed: u0
      }
    )
    (ok true)
  )
)

(define-read-only (get-character-stats (user principal))
  (ok (default-to
    {
      level: u0,
      experience: u0,
      quests-completed: u0
    }
    (map-get? characters user)
  ))
)

;; Quest Management
(define-public (create-quest (title (string-utf8 100)) (difficulty uint))
  (let
    (
      (quest-id (var-get quest-counter))
      (exp-reward (* difficulty u100))
    )
    (map-set quests quest-id
      {
        creator: tx-sender,
        title: title,
        difficulty: difficulty,
        experience-reward: exp-reward,
        completed: false
      }
    )
    (var-set quest-counter (+ quest-id u1))
    (ok quest-id)
  )
)

(define-public (complete-quest (quest-id uint))
  (let
    (
      (quest (unwrap! (map-get? quests quest-id) err-not-found))
      (char (unwrap! (map-get? characters tx-sender) err-unauthorized))
    )
    (asserts! (not (get completed quest)) (err u403))
    (map-set quests quest-id (merge quest { completed: true }))
    (map-set characters tx-sender
      (merge char
        {
          experience: (+ (get experience char) (get experience-reward quest)),
          quests-completed: (+ (get quests-completed char) u1)
        }
      )
    )
    (try! (check-level-up tx-sender))
    (ok true)
  )
)

;; Level Management
(define-private (check-level-up (user principal))
  (let
    (
      (char (unwrap! (map-get? characters user) err-unauthorized))
      (current-level (get level char))
      (exp (get experience char))
      (exp-needed (* current-level u1000))
    )
    (if (>= exp exp-needed)
      (map-set characters user
        (merge char
          {
            level: (+ current-level u1),
            experience: (- exp exp-needed)
          }
        )
      )
      true
    )
    (ok true)
  )
)
