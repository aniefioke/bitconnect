;; BitConnect Pro: Next-Generation Social Network on Bitcoin Layer 2
;;
;; A revolutionary decentralized social networking platform that harnesses
;; the security and immutability of Bitcoin through Stacks Layer 2 technology.
;; BitConnect Pro reimagines social interactions with cryptographic privacy,
;; sovereign identity control, and censorship-resistant communication.
;;
;; Core Innovation:
;; - Bitcoin-secured social graph with cryptographic relationship verification
;; - Zero-knowledge privacy controls for granular data sovereignty  
;; - Intelligent rate limiting prevents spam while preserving user experience
;; - Advanced batch processing optimizes blockchain efficiency and costs
;; - Self-sovereign identity with optional encryption for sensitive data
;; - Distributed friendship protocols with multi-layered consent mechanisms
;;
;; Built for the Bitcoin economy - where your social connections are as 
;; secure and permanent as your Bitcoin holdings.

;; ERROR HANDLING SYSTEM

(define-constant ERR_NOT_FOUND (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_UNAUTHORIZED (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_BLOCKED (err u104))
(define-constant ERR_DEACTIVATED (err u105))
(define-constant ERR_RATE_LIMITED (err u106))
(define-constant ERR_BATCH_FULL (err u107))
(define-constant ERR_BATCH_EXPIRED (err u108))

;; SYSTEM STATUS DEFINITIONS

;; User account states
(define-constant STATUS_DEACTIVATED u0)
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_SUSPENDED u2)

;; Friendship relationship states
(define-constant FRIENDSHIP_PENDING u0)
(define-constant FRIENDSHIP_ACTIVE u1)
(define-constant FRIENDSHIP_BLOCKED u2)

;; RATE LIMITING & SPAM PROTECTION

(define-constant MAX_ACTIONS_PER_DAY u100)
(define-constant MAX_FRIEND_REQUESTS_PER_DAY u20)
(define-constant MAX_STATUS_UPDATES_PER_DAY u24)
(define-constant RATE_LIMIT_RESET_PERIOD u86400) ;; 24 hours in seconds

;; BATCH PROCESSING OPTIMIZATION

(define-constant MIN_BATCH_SIZE u10)
(define-constant MAX_BATCH_SIZE u100)
(define-constant BATCH_EXPIRY_PERIOD u3600) ;; 1 hour in seconds

;; DATA STRUCTURES & STORAGE MAPS

;; Core user identity and profile data
(define-map Users
  principal
  {
    name: (string-ascii 64),
    status: uint,
    timestamp: uint,
    metadata: (optional (string-utf8 256)),
    deactivation-time: (optional uint),
    encryption-key: (optional (buff 32)),
    profile-image: (optional (string-utf8 256)),
  }
)

;; Granular privacy control system
(define-map UserPrivacy
  principal
  {
    friend-list-visible: bool,
    status-visible: bool,
    metadata-visible: bool,
    last-seen-visible: bool,
    profile-image-visible: bool,
    encryption-enabled: bool,
    last-updated: uint,
  }
)

;; Anti-spam rate limiting tracker
(define-map RateLimits
  principal
  {
    daily-actions: uint,
    friend-requests: uint,
    status-updates: uint,
    last-reset: uint,
  }
)

;; Intelligent batch processing state
(define-map UserBatches
  principal
  {
    message-counter: uint,
    last-batch-timestamp: uint,
    batch-size: uint,
    current-batch-items: uint,
    total-batches: uint,
  }
)

;; Comprehensive user activity analytics
(define-map UserActivity
  principal
  {
    last-seen: uint,
    login-count: uint,
    total-actions: uint,
    last-action: uint,
  }
)

;; Decentralized friendship management
(define-map Friendships
  {
    user1: principal,
    user2: principal,
  }
  { status: uint }
)

;; User blocking and safety mechanisms
(define-map BlockedUsers
  {
    blocker: principal,
    blocked: principal,
  }
  { timestamp: uint }
)

;; PRIVATE UTILITY FUNCTIONS

;; Intelligent rate limiting with automatic reset
(define-private (check-rate-limit
    (user principal)
    (action-type uint)
  )
  (let (
      (rate-data (default-to {
        daily-actions: u0,
        friend-requests: u0,
        status-updates: u0,
        last-reset: stacks-block-height,
      }
        (map-get? RateLimits user)
      ))
      (current-time stacks-block-height)
      (should-reset (> (- current-time (get last-reset rate-data)) RATE_LIMIT_RESET_PERIOD))
    )
    (if should-reset
      ;; Reset counters if period expired
      (begin
        (map-set RateLimits user {
          daily-actions: u1,
          friend-requests: (if (is-eq action-type u1)
            u1
            u0
          ),
          status-updates: (if (is-eq action-type u2)
            u1
            u0
          ),
          last-reset: current-time,
        })
        true
      )
      ;; Check limits
      (and
        (< (get daily-actions rate-data) MAX_ACTIONS_PER_DAY)
        (or
          (not (is-eq action-type u1))
          (< (get friend-requests rate-data) MAX_FRIEND_REQUESTS_PER_DAY)
        )
        (or
          (not (is-eq action-type u2))
          (< (get status-updates rate-data) MAX_STATUS_UPDATES_PER_DAY)
        )
      )
    )
  )
)

;; Update rate limit counters after successful action
(define-private (update-rate-limit
    (user principal)
    (action-type uint)
  )
  (let ((rate-data (unwrap-panic (map-get? RateLimits user))))
    (map-set RateLimits user
      (merge rate-data {
        daily-actions: (+ (get daily-actions rate-data) u1),
        friend-requests: (+ (get friend-requests rate-data)
          (if (is-eq action-type u1)
            u1
            u0
          )),
        status-updates: (+ (get status-updates rate-data)
          (if (is-eq action-type u2)
            u1
            u0
          )),
      })
    )
  )
)