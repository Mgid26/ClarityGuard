# ClarityGuard

## Table of Contents
* Introduction
* System Architecture
* Key Features
* Technical Specification
* Smart Contract API
    * Private Functions
    * Public Functions
    * Read-Only Functions
* Error Codes
* Security and Governance
* Contribution Guidelines
* License

---

## Introduction
I am pleased to present **ClarityGuard**, a robust, decentralized registry designed for the storage and verification of AI-generated NFT fingerprints on the Stacks blockchain. In an era where digital content can be easily replicated, ClarityGuard provides a cryptographic layer of defense. By leveraging authorized AI oracle nodes, this protocol transforms visual and auditory traits into 32-byte unique fingerprints, enabling automated duplicate detection and cross-contract authenticity verification.

The primary goal of ClarityGuard is to protect creators and collectors from the proliferation of "copymints"—unauthorized duplicates of existing NFTs—by providing an immutable ledger of content hashes that can be queried by marketplaces, wallets, and decentralized applications.

---

## System Architecture
The protocol operates through a multi-tiered trust model:
1.  **Contract Owner:** The administrative entity capable of managing the node whitelist and handling emergency system pauses.
2.  **Authorized AI Nodes:** Specialized oracle entities permitted to write fingerprint data and submit similarity reports.
3.  **The Registry:** A series of interconnected data maps storing fingerprints, similarity scores, and dispute statuses.

---

## Key Features
* **Cryptographic Fingerprinting:** Supports 32-byte buffers for high-entropy trait representation.
* **Similarity Scoring:** A built-in reporting mechanism where nodes can flag NFTs that share a similarity score above a specific threshold (e.g., 95%).
* **Dispute Resolution:** A manual override system for the contract owner to resolve false positives or confirm legitimate duplicates.
* **Emergency Circuit Breaker:** The ability to pause all state-changing operations during a vulnerability event or system upgrade.
* **Node Accountability:** A strict authorization mapping ensures only verified AI models contribute to the registry.

---

## Smart Contract API

### Private Functions
These internal methods handle the core logic and permission checks used by public-facing functions.

* **`is-authorized-node (caller principal)`**
    * Checks the `authorized-ai-nodes` map to verify if the provided principal has permission to interact with restricted functions.
* **`is-not-paused`**
    * A utility check that returns a boolean indicating whether the system is currently operational.

### Public Functions
State-changing operations that require transaction signing.

* **`pause-contract` / `resume-contract`**
    * Restricted to the `CONTRACT-OWNER`. Toggles the emergency pause variable.
* **`add-ai-node` / `remove-ai-node`**
    * Manages the whitelist of authorized AI oracles.
* **`register-fingerprint (nft-contract, token-id, fingerprint)`**
    * Allows a node to commit a new 32-byte hash to the registry. Requires that the NFT has not been registered previously.
* **`submit-similarity-report (target-contract, target-token-id, reference-contract, reference-token-id, similarity-score)`**
    * Nodes submit evidence of similarity between two assets. If the `similarity-score` is ≥ 95, the target NFT is automatically placed in a "flagged" state.
* **`resolve-flagged-nft (target-contract, target-token-id, is-duplicate)`**
    * Used by the owner to finalize a dispute. It updates the reason and resolution status of a flagged asset.
* **`update-fingerprint (nft-contract, token-id, new-fingerprint)`**
    * Allows the original registrant node to update a fingerprint, facilitating model upgrades or trait re-analysis.

### Read-Only Functions
Gasless functions used to query the state of the blockchain.

* **`get-fingerprint (nft-contract, token-id)`**
    * Returns the 32-byte hash, the registering node, and the block height of registration.
* **`get-flagged-status (target-contract, target-token-id)`**
    * Returns whether an NFT is currently flagged, the reason for the flag, and if the dispute is resolved.
* **`get-similarity-report (target-contract, target-token-id, reference-contract, reference-token-id)`**
    * Retrieves specific comparison data submitted by an AI node.
* **`get-paused-status`**
    * Returns the current operational state of the contract.

---

## Error Codes
| Constant | Value | Description |
| :--- | :--- | :--- |
| `ERR-UNAUTHORIZED` | `u401` | Caller lacks the necessary permissions (not owner or not authorized node). |
| `ERR-ALREADY-REGISTERED` | `u403` | The NFT fingerprint has already been recorded in the registry. |
| `ERR-NOT-FOUND` | `u404` | The requested fingerprint or record does not exist. |
| `ERR-INVALID-SCORE` | `u405` | Similarity score must be an integer between 0 and 100. |
| `ERR-SAME-AS-REFERENCE` | `u406` | Cannot compare an NFT against itself. |
| `ERR-PAUSED` | `u407` | Contract is currently paused by the administrator. |
| `ERR-ALREADY-RESOLVED` | `u408` | Attempted to resolve a dispute that is already closed. |
| `ERR-NOT-FLAGGED` | `u409` | Attempted to resolve an NFT that is not in the flagged registry. |

---

## Security and Governance
ClarityGuard utilizes a **Strict-Owner Governance** model. While the AI nodes are decentralized in their analysis, the administrative power to pause the contract and manage the node list remains with the `CONTRACT-OWNER`. We recommend that this owner address be a multi-signature wallet or a DAO-controlled contract for production environments to mitigate single-point-of-failure risks.

---

## Contribution Guidelines
I welcome contributions to the ClarityGuard ecosystem! To contribute:
1.  Fork the repository.
2.  Create a new feature branch for your improvements.
3.  Ensure all Clarity functions are accompanied by appropriate unit tests using Clarinet.
4.  Submit a Pull Request with a detailed description of your changes.

---

## License
### MIT License

Copyright (c) 2026 ClarityGuard Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---
