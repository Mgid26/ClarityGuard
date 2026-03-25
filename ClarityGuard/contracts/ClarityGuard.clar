;; contract title
;; decentralized-ai-nft-fingerprinting

;; <add a description here>
;; This contract serves as a decentralized registry for AI-generated NFT fingerprints.
;; Authorized AI oracle nodes can register 32-byte cryptographic fingerprints representing
;; the visual/audio traits of an NFT. This enables duplicate detection and authenticity verification.
;; The contract also includes features for slashing misbehaving nodes, dispute resolution,
;; and pausing the entire system in case of an emergency.

;; constants
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-ALREADY-REGISTERED (err u403))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-SCORE (err u405))
(define-constant ERR-SAME-AS-REFERENCE (err u406))
(define-constant ERR-PAUSED (err u407))
(define-constant ERR-ALREADY-RESOLVED (err u408))
(define-constant ERR-NOT-FLAGGED (err u409))
(define-constant CONTRACT-OWNER tx-sender)

;; data maps and vars
(define-data-var contract-paused bool false)

;; Registry of authorized AI nodes that can submit fingerprints
(define-map authorized-ai-nodes principal bool)

;; Main registry storing the 32-byte AI fingerprint for a given NFT
(define-map nft-fingerprints
    { nft-contract: principal, token-id: uint }
    {
        fingerprint: (buff 32),
        registered-by: principal,
        timestamp: uint
    }
)

;; Registry of similarity reports submitted by AI nodes
(define-map similarity-reports
    {
        target-contract: principal,
        target-token-id: uint,
        reference-contract: principal,
        reference-token-id: uint
    }
    {
        reporter: principal,
        score: uint,
        timestamp: uint
    }
)

;; Registry of flagged NFTs that have been marked as duplicates or highly similar
(define-map flagged-nfts
    { contract: principal, token-id: uint }
    { flagged: bool, reason: (string-ascii 64), resolved: bool }
)

;; private functions

;; @desc Checks if a principal is an authorized AI node
;; @param caller; the principal to check
;; @returns bool; true if authorized, false otherwise
(define-private (is-authorized-node (caller principal))
    (default-to false (map-get? authorized-ai-nodes caller))
)

;; @desc Checks if the contract is paused
;; @returns bool; true if NOT paused, false if paused
(define-private (is-not-paused)
    (not (var-get contract-paused))
)

;; public functions

;; @desc Pauses the contract operations
;; @returns (response bool uint); ok true if successful
(define-public (pause-contract)
    (begin
        ;; Ensure only the contract owner can pause
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (var-set contract-paused true)
        (print { event: "contract-paused", timestamp: block-height })
        (ok true)
    )
)

;; @desc Unpauses the contract operations
;; @returns (response bool uint); ok true if successful
(define-public (resume-contract)
    (begin
        ;; Ensure only the contract owner can resume
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (var-set contract-paused false)
        (print { event: "contract-resumed", timestamp: block-height })
        (ok true)
    )
)

;; @desc Adds a new authorized AI node to the registry
;; @param node; the principal to authorize
;; @returns (response bool uint); ok true if successful
(define-public (add-ai-node (node principal))
    (begin
        ;; Ensure only the contract owner can add nodes
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map-set authorized-ai-nodes node true)
        (print { event: "node-added", node: node })
        (ok true)
    )
)

;; @desc Removes an authorized AI node from the registry
;; @param node; the principal to remove
;; @returns (response bool uint); ok true if successful
(define-public (remove-ai-node (node principal))
    (begin
        ;; Ensure only the contract owner can remove nodes
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (map-delete authorized-ai-nodes node)
        (print { event: "node-removed", node: node })
        (ok true)
    )
)

;; @desc Registers a new AI-generated fingerprint for an NFT
;; @param nft-contract; the principal of the NFT contract
;; @param token-id; the token ID of the NFT
;; @param fingerprint; the 32-byte AI-generated fingerprint
;; @returns (response bool uint); ok true if successful
(define-public (register-fingerprint
    (nft-contract principal)
    (token-id uint)
    (fingerprint (buff 32))
)
    (let
        (
            (caller tx-sender)
            (nft-key { nft-contract: nft-contract, token-id: token-id })
        )
        ;; Check if contract is paused
        (asserts! (is-not-paused) ERR-PAUSED)
        ;; Ensure the caller is an authorized AI node
        (asserts! (is-authorized-node caller) ERR-UNAUTHORIZED)
        ;; Ensure the fingerprint is not already registered
        (asserts! (is-none (map-get? nft-fingerprints nft-key)) ERR-ALREADY-REGISTERED)

        ;; Register the fingerprint
        (map-set nft-fingerprints
            nft-key
            {
                fingerprint: fingerprint,
                registered-by: caller,
                timestamp: block-height
            }
        )
        (print { event: "fingerprint-registered", nft-contract: nft-contract, token-id: token-id, node: caller })
        (ok true)
    )
)

;; @desc Read-only function to retrieve an NFT's fingerprint
;; @param nft-contract; the principal of the NFT contract
;; @param token-id; the token ID of the NFT
;; @returns (response tuple uint); ok tuple if found
(define-read-only (get-fingerprint (nft-contract principal) (token-id uint))
    (ok (map-get? nft-fingerprints { nft-contract: nft-contract, token-id: token-id }))
)

;; @desc Submits a similarity report for an NFT against an existing fingerprint
;; @param target-contract; the contract of the NFT being reported
;; @param target-token-id; the token ID of the NFT being reported
;; @param reference-contract; the contract of the original NFT
;; @param reference-token-id; the token ID of the original NFT
;; @param similarity-score; the AI-calculated similarity score (0-100)
;; @returns (response bool uint); ok true if highly similar and flagged, ok false if just reported
(define-public (submit-similarity-report
    (target-contract principal)
    (target-token-id uint)
    (reference-contract principal)
    (reference-token-id uint)
    (similarity-score uint)
)
    (let
        (
            (reporter tx-sender)
            (reference-key { nft-contract: reference-contract, token-id: reference-token-id })
            (target-key { contract: target-contract, token-id: target-token-id })
        )
        ;; Check if contract is paused
        (asserts! (is-not-paused) ERR-PAUSED)
        ;; Ensure the reporter is an authorized AI node
        (asserts! (is-authorized-node reporter) ERR-UNAUTHORIZED)
        ;; Ensure the reference fingerprint actually exists in the registry
        (asserts! (is-some (map-get? nft-fingerprints reference-key)) ERR-NOT-FOUND)
        ;; Ensure the similarity score is valid (0-100)
        (asserts! (<= similarity-score u100) ERR-INVALID-SCORE)
        ;; Ensure the target is not exactly the same as the reference
        (asserts! (not (and (is-eq target-contract reference-contract) (is-eq target-token-id reference-token-id))) ERR-SAME-AS-REFERENCE)
        
        ;; Register the similarity report
        (map-set similarity-reports
            {
                target-contract: target-contract,
                target-token-id: target-token-id,
                reference-contract: reference-contract,
                reference-token-id: reference-token-id
            }
            {
                reporter: reporter,
                score: similarity-score,
                timestamp: block-height
            }
        )
        
        (print { 
            event: "similarity-reported", 
            target-contract: target-contract, 
            target-token-id: target-token-id, 
            score: similarity-score 
        })
        
        ;; If similarity is extremely high (e.g., >= 95), we auto-flag the target NFT
        (if (>= similarity-score u95)
            (begin
                (map-set flagged-nfts
                    target-key
                    { flagged: true, reason: "High similarity to existing fingerprint", resolved: false }
                )
                (print { event: "nft-flagged", target-contract: target-contract, target-token-id: target-token-id })
                (ok true)
            )
            (ok false)
        )
    )
)

;; @desc Resolves a flagged NFT dispute (Owner only)
;; @param target-contract; the contract of the flagged NFT
;; @param target-token-id; the token ID of the flagged NFT
;; @param is-duplicate; boolean indicating if it was indeed a duplicate
;; @returns (response bool uint); ok true if successful
(define-public (resolve-flagged-nft
    (target-contract principal)
    (target-token-id uint)
    (is-duplicate bool)
)
    (let
        (
            (target-key { contract: target-contract, token-id: target-token-id })
            (flag-data (unwrap! (map-get? flagged-nfts target-key) ERR-NOT-FLAGGED))
        )
        ;; Only owner can resolve disputes
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        ;; Must not be already resolved
        (asserts! (not (get resolved flag-data)) ERR-ALREADY-RESOLVED)

        (map-set flagged-nfts
            target-key
            { 
                flagged: is-duplicate, 
                reason: (if is-duplicate "Confirmed duplicate by owner" "Cleared by owner"), 
                resolved: true 
            }
        )
        (print { event: "dispute-resolved", target-contract: target-contract, target-token-id: target-token-id, is-duplicate: is-duplicate })
        (ok true)
    )
)

;; @desc Read-only function to check if an NFT is flagged
;; @param target-contract; the principal of the NFT contract
;; @param target-token-id; the token ID of the NFT
;; @returns (response tuple uint); ok tuple if found
(define-read-only (get-flagged-status (target-contract principal) (target-token-id uint))
    (ok (map-get? flagged-nfts { contract: target-contract, token-id: target-token-id }))
)

;; @desc Read-only function to retrieve a similarity report
;; @param target-contract; the contract of the NFT being reported
;; @param target-token-id; the token ID of the NFT being reported
;; @param reference-contract; the contract of the original NFT
;; @param reference-token-id; the token ID of the original NFT
;; @returns (response tuple uint); ok tuple if found
(define-read-only (get-similarity-report
    (target-contract principal)
    (target-token-id uint)
    (reference-contract principal)
    (reference-token-id uint)
)
    (ok (map-get? similarity-reports
        {
            target-contract: target-contract,
            target-token-id: target-token-id,
            reference-contract: reference-contract,
            reference-token-id: reference-token-id
        }
    ))
)

;; @desc Read-only function to check if contract is paused
;; @returns (response bool uint); ok bool
(define-read-only (get-paused-status)
    (ok (var-get contract-paused))
)


