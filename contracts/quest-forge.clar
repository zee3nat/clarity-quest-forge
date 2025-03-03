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

;; Class Traits
(define-map class-traits uint
  {
    combat-bonus: uint,
    wisdom-bonus: uint,
    agility-bonus: uint,
    exp-multiplier: uint
  }
)

;; Events
(define-data-var last-event-id uint u0)
(define-map events uint
  {
    event-type: (string-utf8 20),
    user: principal,
    data: (string-utf8 100),
    block: uint
  }
)

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
    created-at: uint,
    quest-type: (string-utf8 20)
  }
)

(define-data-var quest-counter uint u0)

;; Initialize Class Traits
(begin
  (map-set class-traits class-warrior
    {
      combat-bonus: u20,
      wisdom-bonus: u5,
      agility-bonus: u5,
      exp-multiplier: u10
    }
  )
  (map-set class-traits class-mage
    {
      combat-bonus: u5,
      wisdom-bonus: u20,
      agility-bonus: u5,
      exp-multiplier: u10
    }
  )
  (map-set class-traits class-rogue
    {
      combat-bonus: u5,
      wisdom-bonus: u5,
      agility-bonus: u20,
      exp-multiplier: u10
    }
  )
)

;; Event Management
(define-private (emit-event (event-type (string-utf8 20)) (data (string-utf8 100)))
  (let
    ((event-id (var-get last-event-id)))
    (map-set events event-id
      {
        event-type: event-type,
        user: tx-sender,
        data: data,
        block: block-height
      }
    )
    (var-set last-event-id (+ event-id u1))
    true
  )
)

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
    (emit-event "character-created" (concat "Class: " (to-string class)))
    (ok true)
  )
)

;; Enhanced Quest Management
(define-public (create-quest (title (string-utf8 100)) (difficulty uint) (deadline-blocks uint) (quest-type (string-utf8 20)))
  (let
    (
      (quest-id (var-get quest-counter))
      (exp-reward (calculate-base-reward difficulty))
    )
    (asserts! (and (>= difficulty u1) (<= difficulty u10)) err-invalid-difficulty)
    (map-set quests quest-id
      {
        creator: tx-sender,
        title: title,
        difficulty: difficulty,
        experience-reward: exp-reward,
        completed: false,
        deadline: (+ block-height deadline-blocks),
        created-at: block-height,
        quest-type: quest-type
      }
    )
    (var-set quest-counter (+ quest-id u1))
    (emit-event "quest-created" title)
    (ok quest-id)
  )
)

;; Enhanced Quest Completion
(define-public (complete-quest (quest-id uint))
  (let
    (
      (quest (unwrap! (map-get? quests quest-id) err-not-found))
      (char (unwrap! (map-get? characters tx-sender) err-unauthorized))
      (class-bonus (get-class-bonus (get class char) (get quest-type quest)))
      (streak-bonus (calculate-streak-bonus (get quest-streak char)))
      (time-bonus (calculate-time-bonus (get created-at quest) (get deadline quest)))
      (total-reward (+ (get experience-reward quest) class-bonus streak-bonus time-bonus))
    )
    (asserts! (not (get completed quest)) (err u403))
    (asserts! (<= block-height (get deadline quest)) err-quest-expired)
    
    (map-set quests quest-id (merge quest { completed: true }))
    (map-set characters tx-sender
      (merge char
        {
          experience: (+ (get experience char) total-reward),
          quests-completed: (+ (get quests-completed char) u1),
          quest-streak: (+ (get quest-streak char) u1)
        }
      )
    )
    (emit-event "quest-completed" (concat "Reward: " (to-string total-reward)))
    (try! (check-level-up tx-sender))
    (ok total-reward)
  )
)

;; Enhanced Helper Functions
(define-private (calculate-base-reward (difficulty uint))
  (* difficulty u100)
)

(define-private (get-class-bonus (class uint) (quest-type (string-utf8 20)))
  (let
    ((traits (unwrap! (map-get? class-traits class) u0)))
    (match quest-type
      "combat" (get combat-bonus traits)
      "wisdom" (get wisdom-bonus traits)
      "agility" (get agility-bonus traits)
      u0
    )
  )
)

(define-private (calculate-streak-bonus (streak uint))
  (if (>= streak u5)
    u200
    (* streak u20)
  )
)
