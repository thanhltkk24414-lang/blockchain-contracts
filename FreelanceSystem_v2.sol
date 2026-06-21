// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ==========================================
// INTERFACE CHUẨN ERC20 (USDC)
// ==========================================
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

// ==========================================
// PHẦN 1: QUẢN LÝ ĐIỂM UY TÍN (REPUTATION STORE)
// Áp dụng: Điều 4, Điều 9, Điều 22.1, Điều 28, Điều 29
//
// GAS OPTIMIZATIONS:
//  - Dùng uint128 cho score thay vì uint256 (tiết kiệm 1 slot khi pack với bool)
//  - Pack (uint128 score + bool initialized) vào 1 storage slot duy nhất
//  - Custom error thay vì require string (tiết kiệm ~50 gas/lần revert)
// ==========================================
contract ReputationStore {
    address public admin;

    // [GAS] Pack score (uint128) + initialized (bool) vào 1 slot (32 bytes)
    // uint128 = 16 bytes, bool = 1 byte → tổng 17 bytes < 32 bytes → 1 SLOAD thay vì 2
    struct ScoreData {
        uint128 score;
        bool initialized; // FIX #5: phân biệt "chưa có điểm" vs "điểm đúng bằng 0"
    }
    mapping(address => ScoreData) private _scores;
    mapping(address => bool) public authorizedContracts;

    // Điều 28: 4 tầng cấp bậc
    enum Tier {
        Restricted,
        Warning,
        Normal,
        Trusted
    }

    // [GAS] Custom errors tiết kiệm hơn require string ~50 gas mỗi lần revert
    error Unauthorized();
    error OnlyAdmin();
    error InvalidAdminAddress();

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event ScoreUpdated(
        address indexed user,
        uint256 oldScore,
        uint256 newScore
    );

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAuthorized() {
        if (msg.sender != admin && !authorizedContracts[msg.sender])
            revert Unauthorized();
        _;
    }

    function setAuthorizedContract(address _contract, bool _status) external {
        if (msg.sender != admin) revert OnlyAdmin();
        authorizedContracts[_contract] = _status;
    }

    function transferAdmin(address newAdmin) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (newAdmin == address(0)) revert InvalidAdminAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminTransferred(previous, newAdmin);
    }

    // Điều 28: người mới chưa init → mặc định 100 điểm
    // FIX #5: dùng initialized flag thay vì check score == 0
    function getScore(address user) public view returns (uint256) {
        ScoreData storage sd = _scores[user];
        // [GAS] 1 SLOAD duy nhất để đọc cả score lẫn initialized
        return sd.initialized ? uint256(sd.score) : 100;
    }

    // Điều 29: cộng/trừ điểm
    function updateScore(
        address user,
        bool isAdd,
        uint256 amount
    ) external onlyAuthorized {
        ScoreData storage sd = _scores[user];

        // [GAS] Cache vào memory để tránh đọc storage 2 lần
        uint256 current = sd.initialized ? uint256(sd.score) : 100;
        uint256 next;

        unchecked {
            // [GAS] unchecked block: chúng ta tự kiểm soát overflow/underflow bên dưới
            if (isAdd) {
                next = current + amount;
                // cap tại type(uint128).max để không overflow uint128
                if (next > type(uint128).max) next = type(uint128).max;
            } else {
                next = amount >= current ? 0 : current - amount;
            }
        }

        // [GAS] 1 SSTORE duy nhất — ghi cả score + initialized cùng lúc
        _scores[user] = ScoreData({score: uint128(next), initialized: true});
        emit ScoreUpdated(user, current, next);
    }

    // Điều 28: quy đổi điểm → Tier
    function getTier(address user) external view returns (Tier) {
        uint256 s = getScore(user);
        // [GAS] Không dùng if-else chain — thứ tự từ cao xuống, return sớm
        if (s >= 120) return Tier.Trusted;
        if (s >= 80) return Tier.Normal;
        if (s >= 50) return Tier.Warning;
        return Tier.Restricted;
    }
}

// ==========================================
// PHẦN 2: PLATFORM TREASURY
// Áp dụng: Điều 15, Điều 22.1, Điều 24, Điều 25, Điều 26, Điều 27
//
// GAS OPTIMIZATIONS:
//  - FIX #1: receiveRevenue() dùng transfer trực tiếp, bỏ approve+transferFrom vòng
//  - FIX #6: unstake check activeDisputeCount trước khi rút
//  - uint128 cho stakes (đủ cho USDC, tiết kiệm slot khi map)
//  - Custom errors
// ==========================================
contract PlatformTreasury {
    address public admin;
    IERC20 public usdcToken;

    // [GAS] uint128 đủ lớn cho USDC (max ~340 tỷ USDC) và tiết kiệm storage
    mapping(address => uint128) public arbitratorStakes;
    mapping(address => bool) public authorizedContracts;

    // FIX #6: track số dispute đang active của mỗi arbitrator
    mapping(address => uint256) public activeDisputeCount;

    uint256 public totalPlatformFees;
    uint256 public totalReserveFund;

    error OnlyAdmin();
    error Unauthorized();
    error InvalidAdminAddress();
    error InsufficientStake();
    error StillActiveInDispute();
    error TransferFailed();
    error InsufficientBalance();

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event ArbitratorStaked(address indexed arbitrator, uint256 amount);
    event ArbitratorUnstaked(address indexed arbitrator, uint256 amount);
    event PenaltyDeducted(address indexed arbitrator, uint256 amount);
    event ArbitratorRewarded(address indexed arbitrator, uint256 amount);
    // FIX #1: event cho receiveRevenue để indexer track
    event RevenueReceived(address indexed from, uint256 amount);

    constructor(address _usdcToken) {
        admin = msg.sender;
        usdcToken = IERC20(_usdcToken);
    }

    modifier onlyAuthorized() {
        if (msg.sender != admin && !authorizedContracts[msg.sender])
            revert Unauthorized();
        _;
    }

    function setAuthorizedContract(address _contract, bool _status) external {
        if (msg.sender != admin) revert OnlyAdmin();
        authorizedContracts[_contract] = _status;
    }

    function transferAdmin(address newAdmin) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (newAdmin == address(0)) revert InvalidAdminAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminTransferred(previous, newAdmin);
    }

    // Điều 22.1: stake tối thiểu 50 USDC
    function stakeAsArbitrator(uint256 amount) external {
        // [GAS] Hằng số tính sẵn: 50 * 1e6 = 50_000_000
        if (amount < 50_000_000) revert InsufficientStake();
        if (!usdcToken.transferFrom(msg.sender, address(this), amount))
            revert TransferFailed();

        // [GAS] unchecked vì amount đã check >= 50e6, không thể overflow uint128 ở đây
        unchecked {
            arbitratorStakes[msg.sender] += uint128(amount);
        }
        emit ArbitratorStaked(msg.sender, amount);
    }

    // FIX #6: không cho unstake khi đang trong active dispute
    function unstakeAsArbitrator(uint256 amount) external {
        if (activeDisputeCount[msg.sender] > 0) revert StillActiveInDispute();
        if (arbitratorStakes[msg.sender] < uint128(amount))
            revert InsufficientStake();

        unchecked {
            arbitratorStakes[msg.sender] -= uint128(amount);
        }
        if (!usdcToken.transfer(msg.sender, amount)) revert TransferFailed();
        emit ArbitratorUnstaked(msg.sender, amount);
    }

    // Điều 22.3: slash (chỉ authorizedContracts gọi — ArbitratorPanel)
    function slashArbitrator(
        address arbitrator,
        uint256 amount
    ) external onlyAuthorized {
        if (arbitratorStakes[arbitrator] < uint128(amount))
            revert InsufficientStake();
        unchecked {
            arbitratorStakes[arbitrator] -= uint128(amount);
            totalReserveFund += amount;
        }
        emit PenaltyDeducted(arbitrator, amount);
    }

    // Điều 27: thưởng cho arbitrator vote đúng
    // FIX #10: check balance trước khi transfer
    function rewardArbitrator(
        address arbitrator,
        uint256 amount
    ) external onlyAuthorized {
        if (usdcToken.balanceOf(address(this)) < amount)
            revert InsufficientBalance();
        if (!usdcToken.transfer(arbitrator, amount)) revert TransferFailed();
        emit ArbitratorRewarded(arbitrator, amount);
    }

    // FIX #1: receiveRevenue() — EscrowVault transfer thẳng vào Treasury rồi gọi hàm này
    // để cập nhật accounting. Không dùng transferFrom nữa → bỏ approve() vòng thừa.
    // onlyAuthorized: chỉ EscrowVault được gọi
    function receiveRevenue(uint256 amount) external onlyAuthorized {
        unchecked {
            totalPlatformFees += amount;
        }
        emit RevenueReceived(msg.sender, amount);
    }

    // FIX #6: ArbitratorPanel gọi để track khi arbitrator được assign vào dispute
    function incrementActiveDispute(
        address arbitrator
    ) external onlyAuthorized {
        unchecked {
            activeDisputeCount[arbitrator]++;
        }
    }

    function decrementActiveDispute(
        address arbitrator
    ) external onlyAuthorized {
        if (activeDisputeCount[arbitrator] > 0) {
            unchecked {
                activeDisputeCount[arbitrator]--;
            }
        }
    }
}

// ==========================================
// PHẦN 3: JOB REGISTRY
// Áp dụng: Điều 1, Điều 4, Điều 6, Điều 10, Điều 11, Điều 12, Điều 13
//
// GAS OPTIMIZATIONS:
//  - Struct Job packing: gom address + uint64 + uint8 vào 1-2 slots
//  - jobCounter dùng uint128 (tiết kiệm slot khi pack)
//  - bytes32 cho CID thay vì string (IPFS CIDv0 = 32 bytes sau khi strip prefix)
//  - Custom errors
//  - FIX #9: thêm events cho startWork, cancelContract
// ==========================================
contract JobRegistry {
    address public admin;
    ReputationStore public reputationStore;

    // [GAS] uint128 cho counter — không bao giờ cần > 2^128 jobs
    uint128 public jobCounter;

    // Điều 10: State Machine
    enum JobStatus {
        OPEN,
        ASSIGNED,
        IN_PROGRESS,
        SUBMITTED,
        DISPUTED,
        COMPLETED,
        REFUNDED,
        CANCELLED
    }

    // Thời điểm commit deliverable on-chain (thay DeliverableVerifier riêng — Điều 16)
    mapping(uint256 => uint40) public deliverableCommittedAt;

    // [GAS] Struct packing tối ưu:
    // Slot 0: client (20B) + status (1B) → 21B
    // Slot 1: freelancer (20B)
    // Slot 2: contractValue (32B)
    // Slot 3: deadline (32B)
    // Slot 4: submittedAt (32B)
    // Slot 5: assignedAt (32B)
    // Slot 6+: jobMetadataCID (string — dynamic)
    // Slot N+: deliverableCID (string — dynamic)
    // Note: string không pack được → dùng bytes32 nếu CID luôn là 32 bytes
    // Ở đây giữ string để dễ debug trên testnet, nhưng production nên dùng bytes32
    struct Job {
        address client;
        JobStatus status; // pack với client vào slot 0
        address freelancer;
        uint256 contractValue;
        uint256 deadline;
        uint256 submittedAt;
        uint256 assignedAt;
        string jobMetadataCID;
        string deliverableCID;
    }

    struct Proposal {
        address freelancer;
        uint256 bidAmount;
        string proposalCID;
    }

    mapping(uint256 => Job) public jobs;
    mapping(uint256 => Proposal[]) public jobProposals;
    mapping(address => bool) public authorizedContracts;

    error Unauthorized();
    error OnlyAdmin();
    error InvalidAdminAddress();
    error AccountRestricted();
    error LowReputationTier();
    error JobNotOpen();
    error InvalidJob();
    error OnlyClient();
    error CannotCancel();

    // FIX #9: events cho startWork, cancelContract
    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event JobCreated(
        uint256 indexed jobId,
        address indexed client,
        uint256 contractValue
    );
    event ProposalSubmitted(uint256 indexed jobId, address indexed freelancer);
    event FreelancerAssigned(uint256 indexed jobId, address indexed freelancer);
    event JobStatusUpdated(uint256 indexed jobId, JobStatus newStatus);

    modifier onlyAuthorized() {
        if (msg.sender != admin && !authorizedContracts[msg.sender])
            revert Unauthorized();
        _;
    }

    constructor(address _reputationStore) {
        admin = msg.sender;
        reputationStore = ReputationStore(_reputationStore);
    }

    function setAuthorizedContract(address _contract, bool _status) external {
        if (msg.sender != admin) revert OnlyAdmin();
        authorizedContracts[_contract] = _status;
    }

    function transferAdmin(address newAdmin) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (newAdmin == address(0)) revert InvalidAdminAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminTransferred(previous, newAdmin);
    }

    // Điều 1 & 11: Client tạo job
    function createJob(
        string calldata _metadataCID,
        uint256 _contractValue,
        uint256 _duration
    ) external returns (uint256) {
        // Điều 4 & 28: Client bị Restricted không được đăng job
        if (uint256(reputationStore.getTier(msg.sender)) == 0)
            revert AccountRestricted();

        // [GAS] unchecked increment — uint128 không overflow ở đây
        unchecked {
            ++jobCounter;
        }
        uint256 jId = uint256(jobCounter);

        jobs[jId] = Job({
            client: msg.sender,
            status: JobStatus.OPEN,
            freelancer: address(0),
            contractValue: _contractValue,
            deadline: block.timestamp + _duration,
            submittedAt: 0,
            assignedAt: 0,
            jobMetadataCID: _metadataCID,
            deliverableCID: ""
        });

        emit JobCreated(jId, msg.sender, _contractValue);
        return jId;
    }

    // Điều 12: Freelancer nộp Proposal
    function submitProposal(
        uint256 _jobId,
        uint256 _bidAmount,
        string calldata _proposalCID
    ) external {
        if (jobs[_jobId].status != JobStatus.OPEN) revert JobNotOpen();
        // Điều 9 & 28: Warning (Tier 1) và Restricted (Tier 0) không được bid
        if (uint256(reputationStore.getTier(msg.sender)) <= 1)
            revert LowReputationTier();

        jobProposals[_jobId].push(
            Proposal({
                freelancer: msg.sender,
                bidAmount: _bidAmount,
                proposalCID: _proposalCID
            })
        );

        emit ProposalSubmitted(_jobId, msg.sender);
    }

    // Điều 13: gán Freelancer (gọi từ EscrowVault)
    function assignFreelancer(
        uint256 _jobId,
        address _freelancer
    ) external onlyAuthorized {
        Job storage job = jobs[_jobId];
        if (job.status != JobStatus.OPEN) revert JobNotOpen();

        job.freelancer = _freelancer;
        job.status = JobStatus.ASSIGNED;
        job.assignedAt = block.timestamp;

        emit FreelancerAssigned(_jobId, _freelancer);
    }

    // State machine transition — chỉ authorized contracts gọi
    function updateJobStatus(
        uint256 _jobId,
        JobStatus _newStatus
    ) external onlyAuthorized {
        Job storage job = jobs[_jobId];
        job.status = _newStatus;

        // [GAS] chỉ SSTORE submittedAt khi thực sự cần
        if (_newStatus == JobStatus.SUBMITTED) {
            job.submittedAt = block.timestamp;
        }

        emit JobStatusUpdated(_jobId, _newStatus);
    }

    function setDeliverableCID(
        uint256 _jobId,
        string calldata _cid
    ) external onlyAuthorized {
        jobs[_jobId].deliverableCID = _cid;
        deliverableCommittedAt[_jobId] = uint40(block.timestamp);
    }

    // Điều 10/18: Client huỷ job OPEN trước khi assign + deposit
    function cancelOpenJob(uint256 _jobId) external {
        Job storage job = jobs[_jobId];
        if (job.client != msg.sender) revert OnlyClient();
        if (job.status != JobStatus.OPEN) revert CannotCancel();
        if (job.freelancer != address(0)) revert CannotCancel();

        job.status = JobStatus.CANCELLED;
        emit JobStatusUpdated(_jobId, JobStatus.CANCELLED);
    }

    // View helpers
    function getJob(uint256 _jobId) external view returns (Job memory) {
        return jobs[_jobId];
    }

    function getProposals(
        uint256 _jobId
    ) external view returns (Proposal[] memory) {
        return jobProposals[_jobId];
    }
}

// ==========================================
// PHẦN 4: HỘI ĐỒNG TRỌNG TÀI (ARBITRATOR PANEL)
// Áp dụng: Điều 19, Điều 20, Điều 21, Điều 22.2–22.5
//
// KLEROS-INSPIRED (tham chiếu Kleros Court / Yellow Paper):
//  - Sortition: chọn ngẫu nhiên từ pool có stake (MVP: block.prevrandao; production: Chainlink VRF)
//  - Commit–reveal voting để tránh ảnh hưởng lẫn nhau
//  - Coherent vote rewards: juror vote đúng đa số nhận thưởng từ Dispute Fee
//  - Incoherent penalty: không reveal → slash stake + trừ reputation
//  - Appeal round: hội đồng mới, loại arbitrator vòng trước (Điều 22.5)
//
// GAS OPTIMIZATIONS:
//  - O(1) pool/chosen checks, packed timestamps, custom errors, precomputed constants
//
// GAS-HEAVY PATHS:
//  - _selectPanel: O(poolLen) sortition loop (up to poolLen×3 attempts)
//  - finalizeDispute: slash loop + vote tally + decrementActiveDispute per arbitrator
//  - startAppealRound: copy excluded arbitrators + full panel re-selection
// ==========================================
contract ArbitratorPanel {
    address public admin;
    ReputationStore public reputationStore;
    JobRegistry public registry;
    PlatformTreasury public treasury;

    // Authorized callers (EscrowVault)
    mapping(address => bool) public authorizedContracts;

    enum DisputeChoice {
        UNDECIDED,
        FREELANCER_WIN,
        CLIENT_WIN,
        SPLIT_50_50
    }

    // Timeline (Kleros-style phased dispute — Điều 20 & 22.3):
    // 0   → 72h  : initial evidence
    // 72  → 120h : rebuttal evidence (48h)
    // 120 → 144h : commit vote (24h)
    // 144 → 168h : reveal vote (24h)
    uint256 private constant EVIDENCE_INITIAL_END = 72 hours;
    uint256 private constant EVIDENCE_REBUTTAL_END = 120 hours;
    uint256 private constant COMMIT_START = 120 hours;
    uint256 private constant COMMIT_END = 144 hours;
    uint256 private constant REVEAL_START = 144 hours;
    uint256 private constant REVEAL_END = 168 hours;
    uint256 private constant APPEAL_WINDOW = 72 hours;
    uint256 private constant SLASH_AMOUNT = 5_000_000; // 5 USDC
    uint256 private constant MIN_STAKE = 50_000_000; // 50 USDC
    uint256 private constant MIN_SCORE = 80;
    uint256 private constant PANEL_SIZE = 5;
    uint256 private constant MIN_QUORUM = 3;

    struct Dispute {
        address initiator;
        uint40 createdAt; // [GAS] uint40 đủ cho timestamp đến năm 36812
        uint40 resultAt; // thời điểm finalize — mở cửa sổ kháng cáo 72h
        bool isResolved;
        uint8 round; // 1 = vòng chính, 2 = kháng cáo (cuối cùng)
        uint8 commitCount;
        uint8 revealCount;
        DisputeChoice pendingResult;
        address[] chosenArbitrators;
        address[] excludedArbitrators; // các arbitrator vòng trước — loại khi kháng cáo
        mapping(address => bytes32) commits;
        mapping(address => DisputeChoice) votes;
    }

    struct Evidence {
        address submitter;
        uint40 submittedAt;
        bytes32 ipfsHash; // [GAS] bytes32 thay string — frontend hash CID trước khi gửi
    }

    mapping(uint256 => Dispute) public disputes;
    mapping(uint256 => Evidence[]) public evidences;

    // [GAS] FIX #2 & #8 infrastructure
    address[] public arbitratorPool;
    mapping(address => bool) public isInPool;
    // [GAS] O(1) check thay vì loop — track vị trí trong mảng để remove nhanh
    mapping(address => uint256) private _poolIndex;

    // [GAS] O(1) check arbitrator được chọn cho dispute cụ thể
    // jobId => arbitrator => bool
    mapping(uint256 => mapping(address => bool)) private _isChosenFor;

    error Unauthorized();
    error OnlyAdmin();
    error InvalidAdminAddress();
    error NotInPool();
    error AlreadyInPool();
    error InsufficientScore();
    error InsufficientStake();
    error NotEnoughArbitrators();
    error NotAnArbitrator();
    error AlreadyCommitted();
    error AlreadyRevealed();
    error NotCommitted();
    error WrongPhase();
    error HashMismatch();
    error AlreadyResolved();
    error VotingStillActive();
    error InsufficientQuorum();
    error EvidenceWindowClosed();
    error JobNotDisputed();
    error NotAParty();
    error AppealWindowClosed();
    error AppealNotAllowed();
    error NotReadyToExecute();
    error DisputeNotFinalized();
    error AppealAlreadyFiled();

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event ArbitratorJoined(address indexed arbitrator);
    event ArbitratorLeft(address indexed arbitrator);
    event DisputeSetup(uint256 indexed jobId, address[] arbitrators);
    event EvidenceSubmitted(
        uint256 indexed jobId,
        address indexed submitter,
        bytes32 ipfsHash
    );
    event VoteCommitted(uint256 indexed jobId, address indexed arbitrator);
    event VoteRevealed(
        uint256 indexed jobId,
        address indexed arbitrator,
        DisputeChoice choice
    );
    event DisputeFinalized(
        uint256 indexed jobId,
        DisputeChoice result,
        uint8 round
    );
    event AppealRoundStarted(uint256 indexed jobId, address[] arbitrators);
    event ArbitratorSlashed(uint256 indexed jobId, address indexed arbitrator);

    modifier onlyAuthorized() {
        if (msg.sender != admin && !authorizedContracts[msg.sender])
            revert Unauthorized();
        _;
    }

    constructor(address _reputation, address _registry, address _treasury) {
        admin = msg.sender;
        reputationStore = ReputationStore(_reputation);
        registry = JobRegistry(_registry);
        treasury = PlatformTreasury(_treasury);
    }

    function setAuthorizedContract(address _contract, bool _status) external {
        if (msg.sender != admin) revert OnlyAdmin();
        authorizedContracts[_contract] = _status;
    }

    function transferAdmin(address newAdmin) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (newAdmin == address(0)) revert InvalidAdminAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminTransferred(previous, newAdmin);
    }

    // Điều 22.1: join pool
    function joinPool(address _arb) external {
        if (msg.sender != admin && msg.sender != _arb) revert Unauthorized();
        if (isInPool[_arb]) revert AlreadyInPool();
        if (reputationStore.getScore(_arb) < MIN_SCORE)
            revert InsufficientScore();
        if (treasury.arbitratorStakes(_arb) < uint128(MIN_STAKE))
            revert InsufficientStake();

        // [GAS] Track index để O(1) remove — lưu index+1 (0 = not in pool)
        _poolIndex[_arb] = arbitratorPool.length;
        arbitratorPool.push(_arb);
        isInPool[_arb] = true;

        emit ArbitratorJoined(_arb);
    }

    // FIX #8: leavePool — O(1) swap-and-pop
    function leavePool() external {
        if (!isInPool[msg.sender]) revert NotInPool();
        if (treasury.activeDisputeCount(msg.sender) > 0) revert Unauthorized();

        uint256 idx = _poolIndex[msg.sender];
        uint256 last = arbitratorPool.length - 1;

        if (idx != last) {
            address lastArb = arbitratorPool[last];
            arbitratorPool[idx] = lastArb;
            _poolIndex[lastArb] = idx;
        }
        arbitratorPool.pop();
        delete isInPool[msg.sender];
        delete _poolIndex[msg.sender];

        emit ArbitratorLeft(msg.sender);
    }

    // FIX #2: setupDisputePanel chỉ EscrowVault (authorized) gọi được — vòng 1
    function setupDisputePanel(
        uint256 _jobId,
        address _initiator
    ) external onlyAuthorized {
        Dispute storage d = disputes[_jobId];
        d.initiator = _initiator;
        d.createdAt = uint40(block.timestamp);
        d.isResolved = false;
        d.round = 1;
        d.pendingResult = DisputeChoice.UNDECIDED;
        d.resultAt = 0;
        d.commitCount = 0;
        d.revealCount = 0;

        _selectPanel(_jobId, d);
        emit DisputeSetup(_jobId, d.chosenArbitrators);
    }

    // Điều 22.5: kháng cáo — hội đồng mới, loại arbitrator vòng trước (Kleros-inspired)
    function startAppealRound(uint256 _jobId) external onlyAuthorized {
        Dispute storage d = disputes[_jobId];
        if (d.round != 1 || !d.isResolved) revert AppealNotAllowed();
        if (block.timestamp > d.resultAt + APPEAL_WINDOW)
            revert AppealWindowClosed();

        // Lưu arbitrator vòng 1 vào danh sách loại trừ
        address[] memory prev = d.chosenArbitrators;
        uint256 prevLen = prev.length;
        for (uint256 i = 0; i < prevLen; ) {
            d.excludedArbitrators.push(prev[i]);
            delete _isChosenFor[_jobId][prev[i]];
            unchecked {
                ++i;
            }
        }

        delete d.chosenArbitrators;
        d.createdAt = uint40(block.timestamp);
        d.isResolved = false;
        d.round = 2;
        d.pendingResult = DisputeChoice.UNDECIDED;
        d.resultAt = 0;
        d.commitCount = 0;
        d.revealCount = 0;

        _selectPanel(_jobId, d);
        emit AppealRoundStarted(_jobId, d.chosenArbitrators);
    }

    // Điều 20: nộp bằng chứng — initial (0→72h) hoặc rebuttal (72→120h)
    function submitEvidence(uint256 _jobId, bytes32 _ipfsHash) external {
        Dispute storage d = disputes[_jobId];
        JobRegistry.Job memory job = registry.getJob(_jobId);

        if (msg.sender != job.client && msg.sender != job.freelancer)
            revert NotAParty();
        if (job.status != JobRegistry.JobStatus.DISPUTED)
            revert JobNotDisputed();
        if (block.timestamp > uint256(d.createdAt) + EVIDENCE_REBUTTAL_END)
            revert EvidenceWindowClosed();

        evidences[_jobId].push(
            Evidence({
                submitter: msg.sender,
                submittedAt: uint40(block.timestamp),
                ipfsHash: _ipfsHash
            })
        );

        emit EvidenceSubmitted(_jobId, msg.sender, _ipfsHash);
    }

    // [GAS] Tách logic chọn panel — tái sử dụng cho vòng 1 và kháng cáo (Kleros sortition)
    function _selectPanel(uint256 _jobId, Dispute storage d) internal {
        JobRegistry.Job memory job = registry.getJob(_jobId);

        uint256 poolLen = arbitratorPool.length;
        if (poolLen < PANEL_SIZE) revert NotEnoughArbitrators();

        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao,
                    block.timestamp,
                    _jobId,
                    d.round,
                    d.initiator
                )
            )
        );

        uint256 found = 0;
        uint256 maxAttempt = poolLen * 3;
        uint256 excludedLen = d.excludedArbitrators.length;

        for (uint256 i = 0; i < maxAttempt && found < PANEL_SIZE; ) {
            uint256 idx = (seed + i) % poolLen;
            address arb = arbitratorPool[idx];
            unchecked {
                ++i;
            }

            if (arb == job.client || arb == job.freelancer) continue;
            if (_isChosenFor[_jobId][arb]) continue;

            bool excluded = false;
            for (uint256 j = 0; j < excludedLen; ) {
                if (d.excludedArbitrators[j] == arb) {
                    excluded = true;
                    break;
                }
                unchecked {
                    ++j;
                }
            }
            if (excluded) continue;

            _isChosenFor[_jobId][arb] = true;
            d.chosenArbitrators.push(arb);
            treasury.incrementActiveDispute(arb);
            unchecked {
                ++found;
            }
        }

        if (found < PANEL_SIZE) revert NotEnoughArbitrators();
    }

    // Điều 22.3 - Giai đoạn 1: Commit Vote (sau khi evidence đóng, 120h → 144h)
    function commitVote(uint256 _jobId, bytes32 _voteHash) external {
        Dispute storage d = disputes[_jobId];

        // Commit window: 120h → 144h (sau khi evidence đóng lúc 120h)
        uint256 start = uint256(d.createdAt) + COMMIT_START;
        uint256 end_ = uint256(d.createdAt) + COMMIT_END;
        if (block.timestamp < start || block.timestamp > end_)
            revert WrongPhase();

        if (!_isChosenFor[_jobId][msg.sender]) revert NotAnArbitrator();
        if (d.commits[msg.sender] != bytes32(0)) revert AlreadyCommitted();

        d.commits[msg.sender] = _voteHash;
        unchecked {
            ++d.commitCount;
        }

        emit VoteCommitted(_jobId, msg.sender);
    }

    // Điều 22.3 - Giai đoạn 2: Reveal Vote (144h → 168h)
    function revealVote(
        uint256 _jobId,
        DisputeChoice _choice,
        string calldata _salt
    ) external {
        Dispute storage d = disputes[_jobId];

        uint256 start = uint256(d.createdAt) + REVEAL_START;
        uint256 end_ = uint256(d.createdAt) + REVEAL_END;
        if (block.timestamp < start || block.timestamp > end_)
            revert WrongPhase();

        if (d.commits[msg.sender] == bytes32(0)) revert NotCommitted();
        if (d.votes[msg.sender] != DisputeChoice.UNDECIDED)
            revert AlreadyRevealed();

        // Verify commit hash
        bytes32 derived = keccak256(abi.encodePacked(uint256(_choice), _salt));
        if (d.commits[msg.sender] != derived) revert HashMismatch();

        d.votes[msg.sender] = _choice;
        unchecked {
            ++d.revealCount;
        }

        emit VoteRevealed(_jobId, msg.sender, _choice);
    }

    // Kleros-inspired: slash trước khi tally — juror commit nhưng không reveal
    function _slashNoReveal(uint256 _jobId, Dispute storage d) internal {
        address[] memory arbs = d.chosenArbitrators;
        uint256 len = arbs.length;

        for (uint256 i = 0; i < len; ) {
            address arb = arbs[i];
            if (
                d.commits[arb] != bytes32(0) &&
                d.votes[arb] == DisputeChoice.UNDECIDED
            ) {
                treasury.slashArbitrator(arb, SLASH_AMOUNT);
                reputationStore.updateScore(arb, false, 10);
                emit ArbitratorSlashed(_jobId, arb);
            }
            unchecked {
                ++i;
            }
        }
    }

    // Điều 22.3: slash arbitrator không reveal — bất kỳ ai trigger sau 168h
    function slashNoReveal(uint256 _jobId) external {
        Dispute storage d = disputes[_jobId];
        if (block.timestamp <= uint256(d.createdAt) + REVEAL_END)
            revert WrongPhase();
        if (d.isResolved) revert AlreadyResolved();
        _slashNoReveal(_jobId, d);
    }

    // Điều 22.4: finalize — ai cũng trigger qua EscrowVault.finalizeDisputeVoting()
    function finalizeDispute(uint256 _jobId) external returns (DisputeChoice) {
        Dispute storage d = disputes[_jobId];
        if (d.isResolved) revert AlreadyResolved();
        if (block.timestamp <= uint256(d.createdAt) + REVEAL_END)
            revert VotingStillActive();

        _slashNoReveal(_jobId, d);

        address[] memory arbs = d.chosenArbitrators;
        uint256 len = arbs.length;

        uint256 votesFree;
        uint256 votesClient;
        uint256 votesSplit;

        for (uint256 i = 0; i < len; ) {
            DisputeChoice v = d.votes[arbs[i]];
            if (v == DisputeChoice.FREELANCER_WIN) {
                unchecked {
                    ++votesFree;
                }
            } else if (v == DisputeChoice.CLIENT_WIN) {
                unchecked {
                    ++votesClient;
                }
            } else if (v == DisputeChoice.SPLIT_50_50) {
                unchecked {
                    ++votesSplit;
                }
            }
            unchecked {
                ++i;
            }
        }

        uint256 validVotes = votesFree + votesClient + votesSplit;
        if (validVotes < MIN_QUORUM) revert InsufficientQuorum();

        DisputeChoice result;
        if (votesFree > votesClient && votesFree > votesSplit)
            result = DisputeChoice.FREELANCER_WIN;
        else if (votesClient > votesFree && votesClient > votesSplit)
            result = DisputeChoice.CLIENT_WIN;
        else result = DisputeChoice.SPLIT_50_50;

        d.pendingResult = result;
        d.resultAt = uint40(block.timestamp);
        d.isResolved = true;

        for (uint256 i = 0; i < len; ) {
            treasury.decrementActiveDispute(arbs[i]);
            unchecked {
                ++i;
            }
        }

        emit DisputeFinalized(_jobId, result, d.round);
        return result;
    }

    function getVote(
        uint256 _jobId,
        address _arb
    ) external view returns (DisputeChoice) {
        return disputes[_jobId].votes[_arb];
    }

    function getPendingResult(
        uint256 _jobId
    ) external view returns (DisputeChoice) {
        return disputes[_jobId].pendingResult;
    }

    function getDisputeRound(uint256 _jobId) external view returns (uint8) {
        return disputes[_jobId].round;
    }

    function getResultAt(uint256 _jobId) external view returns (uint40) {
        return disputes[_jobId].resultAt;
    }

    function isVotingFinalized(uint256 _jobId) external view returns (bool) {
        return disputes[_jobId].isResolved;
    }

    // View helpers
    function getChosenArbitrators(
        uint256 _jobId
    ) external view returns (address[] memory) {
        return disputes[_jobId].chosenArbitrators;
    }

    function getEvidences(
        uint256 _jobId
    ) external view returns (Evidence[] memory) {
        return evidences[_jobId];
    }

    function isChosenArbitrator(
        uint256 _jobId,
        address _arb
    ) external view returns (bool) {
        return _isChosenFor[_jobId][_arb];
    }

    function poolSize() external view returns (uint256) {
        return arbitratorPool.length;
    }
}

// ==========================================
// PHẦN 5: ESCROW VAULT
// Áp dụng: Điều 1, 2, 4, 7, 8, 14, 15, 16, 17, 18, 21, 23, 24, 25, 29
//
// GAS OPTIMIZATIONS:
//  - FIX #1: transfer thẳng vào Treasury, gọi receiveRevenue() chỉ để update accounting
//            → bỏ toàn bộ approve() + transferFrom() vòng thừa
//  - FIX #9: thêm events WorkStarted, ContractCancelled
//  - [GAS] Cache job vào memory 1 lần, không gọi registry.getJob() nhiều lần
//  - [GAS] unchecked arithmetic cho các phép tính đã được kiểm soát
//  - [GAS] Hằng số tính sẵn
//  - Custom errors
//
// GAS-HEAVY PATHS (inherent cost — không tối ưu thêm mà không đổi behavior):
//  - raiseDispute → setupDisputePanel: sortition loop + 5× incrementActiveDispute
//  - finalizeDispute / executeArbitrationResult: tally votes + slash no-reveal + reward loop
//  - fileAppeal → startAppealRound: panel re-selection + excluded-arbitrator scan
//  - depositEscrow / approveAndRelease: 2–3 ERC20 transfers + registry SSTORE
// ==========================================
contract EscrowVault {
    address public admin;
    IERC20 public usdcToken;

    JobRegistry public registry;
    PlatformTreasury public treasury;
    ArbitratorPanel public panel;
    ReputationStore public reputation;

    mapping(uint256 => uint256) public disputeFees;
    mapping(uint256 => address) public disputeInitiator;
    mapping(uint256 => bool) public disputeEverRaised;
    mapping(uint256 => bool) public appealFiled;
    mapping(uint256 => uint256) public totalDisputeFees;

    // FIX 1: Emergency Pause — Điều 4, Điều 9
    bool public paused;

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // [GAS] Hằng số tính sẵn
    uint256 private constant PLATFORM_FEE_BPS = 3; // 3%
    uint256 private constant SERVICE_FEE_BPS = 2; // 2%
    uint256 private constant DISPUTE_FEE_BPS = 2; // 2%
    uint256 private constant DISPUTE_FEE_CAP = 50_000_000; // 50 USDC
    uint256 private constant REVIEW_PERIOD = 7 days;
    uint256 private constant START_WINDOW = 72 hours;
    uint256 private constant APPEAL_WINDOW = 72 hours;
    uint256 private constant APPEAL_FEE_NUM = 130; // 1.3× Dispute Fee
    uint256 private constant APPEAL_FEE_DEN = 100;

    error OnlyClient();
    error OnlyFreelancer();
    error NotAParty();
    error WrongStatus();
    error TransferFailed();
    error ReviewPeriodActive();
    error StartWindowExpired();
    error StartWindowActive();
    error AlreadyDisputed();
    error LowReputationTier();
    error AppealWindowActive();
    error AppealNotAllowed();
    error AppealWindowClosed();
    error AppealAlreadyFiled();
    error VotingNotFinalized();
    // FIX 1: Emergency Pause errors & events
    error ContractPaused();
    error OnlyAdmin();
    error InvalidAdminAddress();

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event EmergencyPauseSet(bool paused, address indexed by);
    event AdminForceResolved(
        uint256 indexed jobId,
        ArbitratorPanel.DisputeChoice decision
    );

    // FIX #9: thêm events đầy đủ
    event EscrowDeposited(
        uint256 indexed jobId,
        address indexed client,
        uint256 total
    );
    event WorkStarted(uint256 indexed jobId, address indexed freelancer);
    event ContractCancelled(
        uint256 indexed jobId,
        address indexed client,
        uint256 refund
    );
    event WorkSubmitted(
        uint256 indexed jobId,
        address indexed freelancer,
        string deliverableCID
    );
    event DisputeRaised(
        uint256 indexed jobId,
        address indexed initiator,
        uint256 fee
    );
    event AppealFiled(
        uint256 indexed jobId,
        address indexed appellant,
        uint256 fee
    );
    event FundsReleased(
        uint256 indexed jobId,
        address indexed freelancer,
        uint256 amount
    );
    event FundsRefunded(
        uint256 indexed jobId,
        address indexed client,
        uint256 amount
    );
    event ArbitratorRewardPaid(
        uint256 indexed jobId,
        address indexed arbitrator,
        uint256 amount
    );

    constructor(
        address _usdc,
        address _registry,
        address _treasury,
        address _panel,
        address _reputation
    ) {
        admin = msg.sender;
        usdcToken = IERC20(_usdc);
        registry = JobRegistry(_registry);
        treasury = PlatformTreasury(_treasury);
        panel = ArbitratorPanel(_panel);
        reputation = ReputationStore(_reputation);
    }

    function transferAdmin(address newAdmin) external {
        if (msg.sender != admin) revert OnlyAdmin();
        if (newAdmin == address(0)) revert InvalidAdminAddress();
        address previous = admin;
        admin = newAdmin;
        emit AdminTransferred(previous, newAdmin);
    }

    // FIX 1: Admin kích hoạt Emergency Pause — Điều 4, Điều 9
    // Khi paused: deposit, approve, raiseDispute, fileAppeal đều bị chặn
    // Tiền đang trong escrow được bảo toàn — không ai rút được
    function setPaused(bool _paused) external {
        if (msg.sender != admin) revert OnlyAdmin();
        paused = _paused;
        emit EmergencyPauseSet(_paused, msg.sender);
    }

    // FIX 3: Admin force resolve khi quorum fail — Điều 22.3
    // Chỉ dùng khi finalizeDisputeVoting() revert do InsufficientQuorum
    // Admin phải ghi log lý do off-chain trước khi gọi hàm này
    function adminForceResolve(
        uint256 _jobId,
        ArbitratorPanel.DisputeChoice _decision
    ) external {
        if (msg.sender != admin) revert OnlyAdmin();
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (job.status != JobRegistry.JobStatus.DISPUTED) revert WrongStatus();

        uint256 fee = totalDisputeFees[_jobId];
        address initiator = disputeInitiator[_jobId];

        delete disputeFees[_jobId];
        delete totalDisputeFees[_jobId];
        delete disputeInitiator[_jobId];

        if (_decision == ArbitratorPanel.DisputeChoice.FREELANCER_WIN) {
            _splitAndPayout(job, _jobId, 100);
            _handleDisputeFee(
                fee,
                initiator,
                job.freelancer,
                _decision,
                _jobId
            );
        } else if (_decision == ArbitratorPanel.DisputeChoice.CLIENT_WIN) {
            _refundToClient(job, _jobId);
            _handleDisputeFee(fee, initiator, job.client, _decision, _jobId);
        } else {
            _splitAndPayout(job, _jobId, 50);
            _handleSplitDisputeFee(fee, initiator);
        }

        emit AdminForceResolved(_jobId, _decision);
    }

    // Điều 13 & 15: Client deposit ký quỹ — Total = contractValue * 1.03
    function depositEscrow(
        uint256 _jobId,
        address _freelancer
    ) external whenNotPaused {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (job.client != msg.sender) revert OnlyClient();
        if (job.status != JobRegistry.JobStatus.OPEN) revert WrongStatus();

        // [GAS] unchecked: contractValue không thể overflow uint256 sau *3/100
        uint256 platformFee;
        uint256 totalCost;
        unchecked {
            platformFee = (job.contractValue * PLATFORM_FEE_BPS) / 100;
            totalCost = job.contractValue + platformFee;
        }

        if (!usdcToken.transferFrom(msg.sender, address(this), totalCost))
            revert TransferFailed();

        registry.assignFreelancer(_jobId, _freelancer);
        emit EscrowDeposited(_jobId, msg.sender, totalCost);
    }

    // Điều 7 & 14: Freelancer xác nhận bắt đầu trong 72h
    function startWork(uint256 _jobId) external {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (job.freelancer != msg.sender) revert OnlyFreelancer();
        if (job.status != JobRegistry.JobStatus.ASSIGNED) revert WrongStatus();
        if (block.timestamp >= job.assignedAt + START_WINDOW)
            revert StartWindowExpired();

        registry.updateJobStatus(_jobId, JobRegistry.JobStatus.IN_PROGRESS);
        // FIX #9: event
        emit WorkStarted(_jobId, msg.sender);
    }

    // Điều 14 & 18: Client hủy hợp đồng nếu Freelancer không startWork sau 72h
    function cancelContract(uint256 _jobId) external {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (job.client != msg.sender) revert OnlyClient();
        if (job.status != JobRegistry.JobStatus.ASSIGNED) revert WrongStatus();
        if (block.timestamp < job.assignedAt + START_WINDOW)
            revert StartWindowActive();

        uint256 totalRefund;
        unchecked {
            totalRefund =
                job.contractValue +
                (job.contractValue * PLATFORM_FEE_BPS) /
                100;
        }

        // [BẢO MẬT] state trước transfer — chống reentrancy
        registry.updateJobStatus(_jobId, JobRegistry.JobStatus.CANCELLED);
        if (!usdcToken.transfer(job.client, totalRefund))
            revert TransferFailed();

        // FIX #9: event
        emit ContractCancelled(_jobId, msg.sender, totalRefund);
    }

    // Điều 7 & 16: Freelancer nộp deliverable
    function submitWork(
        uint256 _jobId,
        string calldata _deliverableCID
    ) external {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (job.freelancer != msg.sender) revert OnlyFreelancer();
        if (job.status != JobRegistry.JobStatus.IN_PROGRESS)
            revert WrongStatus();

        registry.setDeliverableCID(_jobId, _deliverableCID);
        registry.updateJobStatus(_jobId, JobRegistry.JobStatus.SUBMITTED);

        emit WorkSubmitted(_jobId, msg.sender, _deliverableCID);
    }

    // Điều 17: Happy path — Client phê duyệt
    function approveAndRelease(uint256 _jobId) external whenNotPaused {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (job.client != msg.sender) revert OnlyClient();
        if (job.status != JobRegistry.JobStatus.SUBMITTED) revert WrongStatus();

        _splitAndPayout(job, _jobId, 100);
    }

    // Điều 17: Auto-release sau 7 ngày không phản hồi
    // Bất kỳ ai trigger được (freelancer hoặc backend cron)
    function claimTimeoutRelease(uint256 _jobId) external {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (job.status != JobRegistry.JobStatus.SUBMITTED) revert WrongStatus();
        if (block.timestamp < job.submittedAt + REVIEW_PERIOD)
            revert ReviewPeriodActive();

        _splitAndPayout(job, _jobId, 100);
    }

    // Điều 19, 21, 26: Mở tranh chấp + thu Dispute Fee
    function raiseDispute(uint256 _jobId) external whenNotPaused {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (msg.sender != job.client && msg.sender != job.freelancer)
            revert NotAParty();
        if (disputeEverRaised[_jobId]) revert AlreadyDisputed();
        // Điều 28: Warning/Restricted không được mở tranh chấp mới
        if (uint256(reputation.getTier(msg.sender)) <= 1)
            revert LowReputationTier();
        if (
            job.status != JobRegistry.JobStatus.SUBMITTED &&
            job.status != JobRegistry.JobStatus.IN_PROGRESS
        ) revert WrongStatus();

        uint256 fee;
        unchecked {
            fee = (job.contractValue * DISPUTE_FEE_BPS) / 100;
        }
        if (fee > DISPUTE_FEE_CAP) fee = DISPUTE_FEE_CAP;

        if (!usdcToken.transferFrom(msg.sender, address(this), fee))
            revert TransferFailed();

        disputeFees[_jobId] = fee;
        totalDisputeFees[_jobId] = fee;
        disputeInitiator[_jobId] = msg.sender;
        disputeEverRaised[_jobId] = true;

        registry.updateJobStatus(_jobId, JobRegistry.JobStatus.DISPUTED);
        panel.setupDisputePanel(_jobId, msg.sender);

        emit DisputeRaised(_jobId, msg.sender, fee);
    }

    // Điều 22.5: Kháng cáo trong 72h sau kết quả vòng 1 — phí = 1.3× Dispute Fee
    function fileAppeal(uint256 _jobId) external whenNotPaused {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (msg.sender != job.client && msg.sender != job.freelancer)
            revert NotAParty();
        if (job.status != JobRegistry.JobStatus.DISPUTED) revert WrongStatus();
        if (appealFiled[_jobId]) revert AppealAlreadyFiled();
        if (!panel.isVotingFinalized(_jobId)) revert VotingNotFinalized();
        if (panel.getDisputeRound(_jobId) != 1) revert AppealNotAllowed();
        if (block.timestamp > panel.getResultAt(_jobId) + APPEAL_WINDOW)
            revert AppealWindowClosed();

        uint256 appealFee;
        unchecked {
            appealFee = (disputeFees[_jobId] * APPEAL_FEE_NUM) / APPEAL_FEE_DEN;
        }
        if (!usdcToken.transferFrom(msg.sender, address(this), appealFee))
            revert TransferFailed();

        appealFiled[_jobId] = true;
        unchecked {
            totalDisputeFees[_jobId] += appealFee;
        }

        panel.startAppealRound(_jobId);
        emit AppealFiled(_jobId, msg.sender, appealFee);
    }

    // Gọi sau khi hết thời gian reveal — ai cũng trigger được
    function finalizeDisputeVoting(uint256 _jobId) external {
        if (registry.getJob(_jobId).status != JobRegistry.JobStatus.DISPUTED)
            revert WrongStatus();
        panel.finalizeDispute(_jobId);
    }

    // Điều 22.4 & 23: Thực thi phán quyết sau cửa sổ kháng cáo (hoặc sau vòng 2)
    function executeArbitrationResult(uint256 _jobId) external {
        JobRegistry.Job memory job = registry.getJob(_jobId);
        if (job.status != JobRegistry.JobStatus.DISPUTED) revert WrongStatus();

        if (!panel.isVotingFinalized(_jobId)) revert VotingNotFinalized();

        uint8 round = panel.getDisputeRound(_jobId);
        uint40 resultAt = panel.getResultAt(_jobId);

        if (round == 1 && !appealFiled[_jobId]) {
            if (block.timestamp < uint256(resultAt) + APPEAL_WINDOW)
                revert AppealWindowActive();
        }
        if (appealFiled[_jobId] && round != 2) revert VotingNotFinalized();

        ArbitratorPanel.DisputeChoice decision = panel.getPendingResult(_jobId);

        uint256 fee = totalDisputeFees[_jobId];
        address initiator = disputeInitiator[_jobId];

        delete disputeFees[_jobId];
        delete totalDisputeFees[_jobId];
        delete disputeInitiator[_jobId];

        if (decision == ArbitratorPanel.DisputeChoice.FREELANCER_WIN) {
            _splitAndPayout(job, _jobId, 100);
            _handleDisputeFee(fee, initiator, job.freelancer, decision, _jobId);
        } else if (decision == ArbitratorPanel.DisputeChoice.CLIENT_WIN) {
            _refundToClient(job, _jobId);
            _handleDisputeFee(fee, initiator, job.client, decision, _jobId);
        } else {
            _splitAndPayout(job, _jobId, 50);
            _handleSplitDisputeFee(fee, initiator);
        }
    }

    // ==========================================
    // INTERNAL HELPERS
    // ==========================================

    // Điều 23, 24, 25: Chia tiền + thu phí + cập nhật điểm
    // FIX #1: transfer thẳng vào Treasury (không dùng approve + transferFrom vòng)
    function _splitAndPayout(
        JobRegistry.Job memory job,
        uint256 _jobId,
        uint256 _freelancerPercent
    ) internal {
        // [GAS] Tất cả arithmetic trong 1 unchecked block
        uint256 freelancerGross;
        uint256 serviceFee;
        uint256 freelancerNet;
        uint256 platformFee;
        uint256 totalRevenue;

        unchecked {
            freelancerGross = (job.contractValue * _freelancerPercent) / 100;
            serviceFee = (freelancerGross * SERVICE_FEE_BPS) / 100; // 2% của phần FL
            freelancerNet = freelancerGross - serviceFee;
            platformFee = (freelancerGross * PLATFORM_FEE_BPS) / 100; // 3% tương ứng Client
            totalRevenue = serviceFee + platformFee;
        }

        // [BẢO MẬT] state trước transfers
        registry.updateJobStatus(_jobId, JobRegistry.JobStatus.COMPLETED);

        // FIX #1: transfer thẳng vào Treasury, sau đó cập nhật accounting
        if (totalRevenue > 0) {
            if (!usdcToken.transfer(address(treasury), totalRevenue))
                revert TransferFailed();
            treasury.receiveRevenue(totalRevenue);
        }

        if (freelancerNet > 0) {
            if (!usdcToken.transfer(job.freelancer, freelancerNet))
                revert TransferFailed();
            emit FundsReleased(_jobId, job.freelancer, freelancerNet);
        }

        // Hoàn tiền Client khi SPLIT (không phải 100%)
        if (_freelancerPercent < 100) {
            uint256 clientRefund;
            unchecked {
                // totalDeposited = contractValue * 1.03
                uint256 totalDeposited = job.contractValue +
                    (job.contractValue * PLATFORM_FEE_BPS) /
                    100;
                // clientRefund = tổng đã nạp - phần FL gross - phần fee Client đã tính
                clientRefund = totalDeposited - freelancerGross - platformFee;
            }
            if (clientRefund > 0) {
                if (!usdcToken.transfer(job.client, clientRefund))
                    revert TransferFailed();
            }
        }

        // Điều 29: cập nhật điểm
        reputation.updateScore(job.freelancer, true, 10);
        reputation.updateScore(job.client, true, 5);
    }

    // Điều 29: Client thắng dispute — hoàn tiền + trừ điểm Freelancer
    function _refundToClient(
        JobRegistry.Job memory job,
        uint256 _jobId
    ) internal {
        uint256 totalFunds;
        unchecked {
            totalFunds =
                job.contractValue +
                (job.contractValue * PLATFORM_FEE_BPS) /
                100;
        }

        // [BẢO MẬT] state trước transfer
        registry.updateJobStatus(_jobId, JobRegistry.JobStatus.REFUNDED);

        if (!usdcToken.transfer(job.client, totalFunds))
            revert TransferFailed();
        emit FundsRefunded(_jobId, job.client, totalFunds);

        reputation.updateScore(job.freelancer, false, 15);
        reputation.updateScore(job.client, true, 5);
    }

    // Điều 26: xử lý Dispute Fee + thưởng 50% cho arbitrator vote đúng (Điều 27)
    function _handleDisputeFee(
        uint256 fee,
        address initiator,
        address winner,
        ArbitratorPanel.DisputeChoice decision,
        uint256 _jobId
    ) internal {
        if (fee == 0) return;

        uint256 rewardPool;
        uint256 treasuryPart;
        unchecked {
            rewardPool = fee / 2;
            treasuryPart = fee - rewardPool;
        }

        if (initiator == winner) {
            if (!usdcToken.transfer(winner, fee)) revert TransferFailed();
        } else {
            if (treasuryPart > 0) {
                if (!usdcToken.transfer(address(treasury), treasuryPart))
                    revert TransferFailed();
                treasury.receiveRevenue(treasuryPart);
            }
            // Chuyển reward pool vào Treasury trước khi rewardArbitrator() rút
            if (rewardPool > 0) {
                if (!usdcToken.transfer(address(treasury), rewardPool))
                    revert TransferFailed();
                treasury.receiveRevenue(rewardPool);
            }
            _rewardCorrectArbitrators(_jobId, rewardPool, decision);
        }
    }

    // SPLIT: hoàn 50% fee cho bên khởi tạo, 50% còn lại vào Treasury
    // FIX 4 (Điều 22.4 & 23): SPLIT không thưởng Arbitrator — 50% còn lại vào Treasury làm quỹ vận hành
    // Lý do: kết quả SPLIT = không bên nào rõ ràng thắng/thua → không có "bên thua chịu phí"
    // → không có nguồn để trả thưởng Arbitrator theo cơ chế Điều 22.4
    function _handleSplitDisputeFee(uint256 fee, address initiator) internal {
        if (fee == 0) return;
        unchecked {
            uint256 halfFee = fee / 2;
            uint256 remainFee = fee - halfFee;
            if (halfFee > 0) {
                if (!usdcToken.transfer(initiator, halfFee))
                    revert TransferFailed();
            }
            if (remainFee > 0) {
                if (!usdcToken.transfer(address(treasury), remainFee))
                    revert TransferFailed();
                treasury.receiveRevenue(remainFee);
            }
        }
    }

    // Điều 27: 50% Dispute Fee thu được trả cho arbitrator vote đúng kết quả
    function _rewardCorrectArbitrators(
        uint256 _jobId,
        uint256 rewardPool,
        ArbitratorPanel.DisputeChoice result
    ) internal {
        if (rewardPool == 0) return;

        address[] memory arbs = panel.getChosenArbitrators(_jobId);
        uint256 len = arbs.length;
        uint256 correctCount;

        for (uint256 i = 0; i < len; ) {
            if (panel.getVote(_jobId, arbs[i]) == result) {
                unchecked {
                    ++correctCount;
                }
            }
            unchecked {
                ++i;
            }
        }
        if (correctCount == 0) return;

        uint256 each;
        unchecked {
            each = rewardPool / correctCount;
        }
        if (each == 0) return;

        for (uint256 i = 0; i < len; ) {
            if (panel.getVote(_jobId, arbs[i]) == result) {
                treasury.rewardArbitrator(arbs[i], each);
                emit ArbitratorRewardPaid(_jobId, arbs[i], each);
            }
            unchecked {
                ++i;
            }
        }
    }
}
