;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u404))
(define-constant err-unauthorized (err u401))
(define-constant err-invalid-level (err u402))
(define-constant err-invalid-difficulty (err u403))
(define-constant err-quest-expired (err u405))
(define-constant err-invalid-class (err u406))

;; Character Classes
(define-constant class-warrior u1)
(define-constant class-mage u2)
(define-constant class-rogue u3)

;; Data Variables
(define-map characters principal
  {
    level: uint,
    experience: uint,
    quests-completed: uint,
    class: uint,
    skill-points: uint,
    quest-streak: uint
  }
)

(define-map quests uint
  {
    creator: principal,
    title: (string-utf8 100),
    difficulty: uint,
    experience-reward: uint,
    completed: bool,
    deadline: uint,
    created-at: uint
  }
)

(define-data-var quest-counter uint u0)

;; Character Management
(define-public (initialize-character (class uint))
  (begin
    (asserts! (or (is-eq class class-warrior)
                 (is-eq class class-mage)
                 (is-eq class class-rogue)) err-invalid-class)
    (map-set characters tx-sender
      {
        level: u1,
        experience: u0,
        quests-completed: u0,
        class: class,
        skill-points: u0,
        quest-streak: u0
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
      quests-completed: u0,
      class: u0,
      skill-points: u0,
      quest-streak: u0
    }
    (map-get? characters user)
  ))
)

;; Quest Management
(define-public (create-quest (title (string-utf8 100)) (difficulty uint) (deadline-blocks uint))
  (let
    (
      (quest-id (var-get quest-counter))
      (exp-reward (* difficulty u100))
    )
    ;; Validate difficulty (1-10)
    (asserts! (and (>= difficulty u1) (<= difficulty u10)) err-invalid-difficulty)
    (map-set quests quest-id
      {
        creator: tx-sender,
        title: title,
        difficulty: difficulty,
        experience-reward: exp-reward,
        completed: false,
        deadline: (+ block-height deadline-blocks),
        created-at: block-height
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
      (bonus-exp (calculate-time-bonus (get created-at quest) (get deadline quest)))
    )
    (asserts! (not (get completed quest)) (err u403))
    (asserts! (<= block-height (get deadline quest)) err-quest-expired)
    
    (map-set quests quest-id (merge quest { completed: true }))
    (map-set characters tx-sender
      (merge char
        {
          experience: (+ (get experience char) 
                       (get experience-reward quest)
                       bonus-exp),
          quests-completed: (+ (get quests-completed char) u1),
          quest-streak: (+ (get quest-streak char) u1)
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
            experience: (- exp exp-needed),
            skill-points: (+ (get skill-points char) u1)
          }
        )
      )
      true
    )
    (ok true)
  )
)

;; Helper Functions
(define-private (calculate-time-bonus (created-at uint) (deadline uint))
  (let
    (
      (time-taken (- block-height created-at))
      (time-allowed (- deadline created-at))
    )
    (if (< time-taken (/ time-allowed u2))
      u100  ;; Bonus for completing early
      u0
    )
  )
)
