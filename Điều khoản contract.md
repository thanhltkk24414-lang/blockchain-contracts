**ĐIỀU KHOẢN HỢP ĐỒNG**

Freelancer DApp — Smart Contract Platform

# **PHẦN I: ĐIỀU KHOẢN DÀNH CHO CLIENT**

## **Điều 1. Điều kiện tạo công việc**

* Client phải sở hữu ví MetaMask hợp lệ và kết nối thành công với mạng Sepolia.
* Client phải xác thực bằng chữ ký SIWE (Sign-In With Ethereum) — không cần email hay mật khẩu.
* Client phải cung cấp đầy đủ thông tin công việc:
  + Tiêu đề công việc.
  + Mô tả công việc chi tiết.
  + Sản phẩm bàn giao (deliverable) cụ thể.
  + Thời gian hoàn thành.
  + Giá trị hợp đồng (USDC).
  + Tiêu chí nghiệm thu rõ ràng.
* Thông tin công việc phải hợp pháp và không vi phạm quy định nền tảng.
* Công việc được tạo on-chain ở trạng thái OPEN ngay khi Client gọi createJob() — metadata (IPFS CID) được lưu trong JobRegistry.
* Công việc chuyển sang ASSIGNED khi Client chọn Freelancer và gọi depositEscrow() (ký quỹ USDC).

## **Điều 2. Nghĩa vụ của Client**

* Cung cấp đầy đủ yêu cầu, tài liệu và tài nguyên cần thiết cho Freelancer.
* Phản hồi các yêu cầu làm rõ công việc trong quá trình thực hiện.
* Kiểm tra và nghiệm thu sản phẩm trong thời gian quy định (07 ngày).
* Thanh toán thông qua cơ chế Escrow của nền tảng — không thanh toán ngoài hệ thống.
* Tạo điều kiện để Freelancer hoàn thành công việc theo thỏa thuận.
* Không được:
  + Thay đổi phạm vi công việc ngoài thỏa thuận ban đầu.
  + Từ chối thanh toán không có căn cứ hợp lệ.
  + Cố tình trì hoãn nghiệm thu.
  + Lạm dụng cơ chế tranh chấp.

## **Điều 3. Quyền của Client**

* Tìm kiếm và lựa chọn Freelancer phù hợp từ danh sách Proposal.
* Quy định thời gian bắt đầu và kết thúc hợp đồng.
* Nhận và đánh giá Proposal từ Freelancer.
* Theo dõi tiến độ thực hiện công việc qua dashboard.
* Yêu cầu chỉnh sửa sản phẩm trong phạm vi hợp đồng.
* Mở tranh chấp khi phát hiện vi phạm.
* Nhận hoàn tiền theo kết quả giải quyết tranh chấp.

## **Điều 4. Xử lý vi phạm đối với Client**

**Smart Contract tự động:**

* Từ chối giải ngân khi hợp đồng đang ở trạng thái DISPUTED.
* Từ chối các giao dịch không hợp lệ (rút tiền khi chưa nghiệm thu, v.v.).
* Khóa hoặc hoàn tiền ký quỹ theo điều kiện hợp đồng.
* Chặn các giao dịch tài chính nhạy cảm khi Emergency Pause đang kích hoạt (xem Điều 4 bên dưới).

**✔ ĐÃ SỬA:** FIX 1 — Emergency Pause đã được implement on-chain trong EscrowVault (hàm setPaused()). Khi paused=true, các hàm sau revert: depositEscrow(), approveAndRelease(), raiseDispute(), fileAppeal(). Các hàm vẫn hoạt động: startWork(), submitWork(), cancelContract(), cancelOpenJob(), claimTimeoutRelease(), finalizeDisputeVoting(), executeArbitrationResult() — tiền trong escrow được bảo toàn, không ai rút trái phép.

**Admin có quyền áp dụng:**

* Kích hoạt Emergency Pause — gọi setPaused(true) trong EscrowVault — tất cả giao dịch bị chặn, tiền trong escrow được bảo toàn.
* Giảm Reputation Score.
* Giới hạn quyền đăng tuyển công việc.
* Khóa tài khoản tạm thời hoặc vĩnh viễn trong trường hợp vi phạm nghiêm trọng.
* Force resolve tranh chấp khi quorum fail — gọi adminForceResolve() (xem Điều 22.3).
* Chuyển quyền Platform Admin on-chain — gọi transferAdmin(newAdmin) trên từng contract (ReputationStore, PlatformTreasury, JobRegistry, ArbitratorPanel, EscrowVault). Deployer là admin ban đầu; sự kiện AdminTransferred được emit để minh bạch.

**Các trường hợp áp dụng:**

* Cung cấp thông tin sai lệch hoặc giả mạo.
* Đăng tải công việc trái pháp luật.
* Gian lận, lừa đảo hoặc thông đồng.
* Lạm dụng cơ chế tranh chấp.
* Vi phạm nhiều lần quy định nền tảng.

## **Điều 5. Quyền sở hữu trí tuệ**

* Trong thời gian hợp đồng chưa hoàn tất thanh toán: Freelancer là chủ sở hữu hợp pháp đối với sản phẩm, source code, thiết kế và tài sản trí tuệ do mình tạo ra. Client chỉ có quyền xem xét, đánh giá và nghiệm thu — không được sử dụng thương mại, phân phối hay công khai.
* Sau khi Freelancer được giải ngân đầy đủ: toàn bộ quyền sở hữu trí tuệ đối với sản phẩm bàn giao được chuyển giao cho Client.
* Freelancer không được tái sử dụng hoặc phân phối sản phẩm dưới bất kỳ hình thức nào nếu không có sự đồng ý từ Client.

**Lưu ý pháp lý:** Điều khoản sở hữu trí tuệ có giá trị ràng buộc pháp lý theo quy định dân sự. Đây KHÔNG phải logic được thực thi tự động bởi Smart Contract — Smart Contract chỉ kiểm soát dòng tiền.

# **PHẦN II: ĐIỀU KHOẢN DÀNH CHO FREELANCER**

## **Điều 6. Điều kiện tham gia nền tảng**

* Freelancer phải sở hữu ví blockchain hợp lệ (MetaMask hoặc tương đương).
* Freelancer phải có hồ sơ nghề nghiệp đang hoạt động.
* Freelancer phải cung cấp: hồ sơ năng lực, kỹ năng chuyên môn, danh mục sản phẩm (Portfolio).

## **Điều 7. Nghĩa vụ của Freelancer**

* Chỉ bắt đầu công việc sau khi hợp đồng đã được ký quỹ và xác nhận on-chain.
* Gọi hàm startWork() để xác nhận bắt đầu trong vòng 72 giờ kể từ khi được assign.
* Thực hiện đúng yêu cầu đã cam kết trong hợp đồng.
* Bàn giao sản phẩm đúng thời hạn.
* Upload deliverable lên IPFS, lấy CID. Gọi submitWork() — CID + deliverableCommittedAt lưu on-chain trong JobRegistry.
* Hỗ trợ chỉnh sửa trong phạm vi hợp đồng.
* Bảo mật thông tin Client trong thời gian thực hiện công việc.
* Không được:
  + Bỏ dở công việc không có lý do chính đáng.
  + Giao sản phẩm đạo văn, chứa mã độc hoặc vi phạm pháp luật.
  + Giao sản phẩm không đúng yêu cầu đã thỏa thuận.
  + Cung cấp bằng chứng giả mạo trong quá trình tranh chấp.

## **Điều 8. Quyền của Freelancer**

* Được xác nhận tiền ký quỹ đã được khóa trong Smart Contract trước khi bắt đầu.
* Được nhận thanh toán tự động khi Client phê duyệt hoặc khi timeout auto-release.
* Được mở tranh chấp nếu quyền lợi bị xâm phạm.
* Được nhận bồi thường theo kết quả giải quyết tranh chấp.
* Được đơn phương yêu cầu giải quyết theo cơ chế trọng tài (Arbitrator Panel) khi Client không phản hồi.

## **Điều 9. Xử lý vi phạm đối với Freelancer**

**Smart Contract tự động:**

* Từ chối giải ngân khi hợp đồng đang ở trạng thái DISPUTED.
* Hoàn tiền cho Client theo kết quả giải quyết tranh chấp.
* Thực hiện khấu trừ phí nền tảng khi release funds.
* Chặn depositEscrow, approveAndRelease, raiseDispute, fileAppeal khi Emergency Pause đang kích hoạt (xem Điều 4).

**Admin có quyền áp dụng:**

* Kích hoạt Emergency Pause (xem Điều 4).
* Giảm Reputation Score.
* Giới hạn quyền gửi Proposal hoặc nhận công việc mới.
* Hạn chế tham gia Arbitrator Panel.
* Khóa tài khoản tạm thời hoặc vĩnh viễn.

**Các trường hợp áp dụng:**

* Không thực hiện công việc sau khi đã nhận nhiệm vụ.
* Bàn giao sản phẩm không đúng cam kết.
* Vi phạm quyền sở hữu trí tuệ hoặc sử dụng trái phép tài sản bên thứ ba.
* Cung cấp bằng chứng giả mạo trong tranh chấp.
* Lạm dụng cơ chế tranh chấp.

# **PHẦN III: QUY ĐỊNH GIAO DỊCH**

## **Điều 10. Trạng thái công việc (Job Status)**

|  |  |  |
| --- | --- | --- |
| **Trạng thái** | **Chuyển sang** | **Điều kiện** |
| OPEN | ASSIGNED | Client chọn freelancer và gọi depositEscrow() |
| OPEN | CANCELLED | Client gọi cancelOpenJob() trước khi ký quỹ |
| ASSIGNED | IN\_PROGRESS | Freelancer gọi startWork() trong 72h |
| ASSIGNED | CANCELLED | Freelancer không gọi startWork() sau 72h → Client cancelContract() |
| IN\_PROGRESS | SUBMITTED | Freelancer gọi submitWork() với IPFS CID |
| IN\_PROGRESS | DISPUTED | Client hoặc Freelancer gọi raiseDispute() |
| SUBMITTED | COMPLETED | Client gọi approveAndRelease() hoặc claimTimeoutRelease() |
| SUBMITTED | DISPUTED | Client hoặc Freelancer gọi raiseDispute() |
| DISPUTED | COMPLETED | Arbitrator Panel: Freelancer thắng hoặc SPLIT\_50\_50 → release/split funds |
| DISPUTED | REFUNDED | Arbitrator Panel: Client thắng → refund về client |

**Lưu ý:** COMPLETED = tiền đến tay Freelancer (happy path hoặc dispute). REFUNDED = tiền trả về Client (client thắng hoặc cancel). Terminal states — không thể chuyển tiếp.

## **Điều 11. Tạo công việc (Create Job)**

* Client đăng công việc trên nền tảng — mỗi công việc được gán một Job ID duy nhất on-chain.
* Metadata công việc (tiêu đề, mô tả, deliverables...) được upload lên IPFS, CID được lưu on-chain trong JobRegistry.
* Công việc ở trạng thái OPEN ngay sau createJob() — Freelancer có thể gửi Proposal. Chuyển ASSIGNED khi Client gọi depositEscrow().

## **Điều 12. Gửi Proposal (Bid)**

* Freelancer được gửi Proposal cho công việc đang OPEN (tier Warning/Restricted bị chặn on-chain).
* Proposal bao gồm: giá đề xuất bidAmount (USDC), nội dung đề xuất proposalCID (IPFS).
* Một công việc có thể nhận nhiều Proposal — Client chọn một.
* **Lưu ý on-chain:** contractValue được Client đặt tại createJob(); bidAmount chỉ mang tính tham khảo off-chain — EscrowVault khóa đúng contractValue khi depositEscrow().

## **Điều 13. Chỉ định Freelancer (Assign)**

* Client có quyền chấp nhận hoặc từ chối Proposal.
* Khi Proposal được chấp nhận: Freelancer được chỉ định, hợp đồng chuyển sang trạng thái ASSIGNED.
* Client thực hiện 2 bước: approve USDC (ERC-20) → depositEscrow() vào EscrowVault.

## **Điều 14. Bắt đầu công việc**

* Freelancer phải xác nhận bắt đầu bằng cách gọi hàm startWork() trong vòng 72 giờ kể từ khi assign.
* Sau khi gọi startWork(): trạng thái chuyển ASSIGNED → IN\_PROGRESS.
* Nếu Freelancer không gọi startWork() trong 72 giờ: Client có quyền gọi cancelContract() → hoàn tiền toàn bộ về Client, trạng thái chuyển sang CANCELLED.

# **PHẦN IV: QUY ĐỊNH ESCROW**

## **Điều 15. Cơ chế ký quỹ (chỉ áp dụng cho Client)**

* Client phải ký quỹ toàn bộ giá trị hợp đồng cộng phí nền tảng vào EscrowVault.
* Tài sản ký quỹ được khóa trong Smart Contract — không bên nào được tự ý rút tiền.

**✔ ĐÃ SỬA:** FIX 2 — Sửa bảng: 'Freelancer nhận = Contract Value' → 'Freelancer nhận (gross) = Contract Value, trước khi trừ Service Fee 2% theo Điều 25'.

|  |  |
| --- | --- |
| **Công thức** | **Giải thích** |
| Total Deposit = Contract Value × 1.03 | Client trả Contract Value + 3% phí nền tảng |
| Freelancer nhận (gross) = Contract Value | Trước khi trừ Service Fee 2% theo Điều 25 |
| Freelancer thực nhận (net) = Contract Value × 0.98 | Sau khi trừ Service Fee 2% |
| Platform Fee = Contract Value × 3% | Chuyển vào PlatformTreasury khi releaseFunds() |

## **Điều 16. Bàn giao sản phẩm**

* Freelancer upload deliverable lên IPFS, lấy CID.
* Gọi submitWork(jobId, deliverableCID) — CID được lưu on-chain trong JobRegistry.
* Sản phẩm có thể bao gồm: source code, file thiết kế, tài liệu kỹ thuật, video demo.
* Sau khi submit on-chain: trạng thái chuyển IN\_PROGRESS → SUBMITTED.

## **Điều 17. Nghiệm thu và Auto-release**

* Sau khi Freelancer submit, Client có 07 ngày để nghiệm thu.
* Trong thời gian nghiệm thu, Client có quyền:
  + Chấp nhận (Approve) → gọi approveAndRelease() → USDC chuyển về ví Freelancer.
  + Yêu cầu chỉnh sửa (Request Revision) → ghi chú off-chain, không ảnh hưởng contract.
  + Mở tranh chấp (Raise Dispute) → gọi raiseDispute() → trạng thái SUBMITTED → DISPUTED.
* Nếu Client không thực hiện bất kỳ hành động nào trong 07 ngày:
  + Freelancer (hoặc backend cron) gọi claimTimeoutRelease().
  + Smart Contract kiểm tra: block.timestamp >= submittedAt + reviewPeriod.
  + Nếu điều kiện thỏa: USDC tự động release cho Freelancer, trạng thái → COMPLETED.
  + Mặc định coi im lặng 07 ngày là chấp thuận — Client có trách nhiệm phản hồi trong hạn.

**Lý do:** Smart Contract không có cron job tự động. claimTimeoutRelease() là hàm bất kỳ ai cũng gọi được sau deadline — backend của nền tảng chạy cron mỗi giờ để trigger, nhưng Freelancer vẫn có thể tự gọi nếu cần.

## **Điều 18. Hủy hợp đồng**

* Job OPEN, chưa ký quỹ: Client gọi cancelOpenJob() → CANCELLED (không phát sinh hoàn tiền vì chưa deposit).
* Job ASSIGNED, Freelancer không gọi startWork() sau 72 giờ: Client gọi cancelContract() → hoàn toàn bộ (contractValue + 3% Platform Fee) → CANCELLED.
* Job ASSIGNED trong vòng 72 giờ đầu: Client **không thể** hủy on-chain — phải chờ hết hạn hoặc thỏa thuận off-chain.
* Sau khi Freelancer đã gọi startWork(): việc hủy hợp đồng phải thông qua cơ chế tranh chấp (raiseDispute).

# **PHẦN V: QUY ĐỊNH GIẢI QUYẾT TRANH CHẤP**

## **Điều 19. Mở tranh chấp**

* Client hoặc Freelancer đều có quyền mở tranh chấp bằng cách gọi raiseDispute() khi hợp đồng ở SUBMITTED hoặc IN\_PROGRESS.
* Người dùng tier Warning hoặc Restricted (Reputation < 80) không được mở tranh chấp mới — enforce on-chain.
* Khi mở tranh chấp, bên khởi tạo phải tạm ứng Dispute Fee (xem Điều 26).
* Mỗi hợp đồng chỉ được mở tối đa 01 lần tranh chấp chính và 01 lần kháng cáo theo Điều 22. Sau khi có quyết định kháng cáo, không còn cơ chế tranh chấp tiếp theo trong cùng hợp đồng.

**19.1 Phạm vi trách nhiệm của Smart Contract:**

* Smart Contract xử lý 01 lần tranh chấp chính (raiseDispute) và tối đa 01 lần kháng cáo (fileAppeal) cho mỗi hợp đồng.
* Mọi khiếu nại phát sinh sau khi Smart Contract đã thực thi kết quả cuối cùng đều nằm ngoài phạm vi xử lý của hệ thống blockchain.

**19.2 Chuyển giao sang cơ chế pháp lý:**

* Trong trường hợp không chấp nhận kết quả sau khi Smart Contract đã thực thi, các bên có quyền khởi kiện ra cơ quan tư pháp có thẩm quyền.
* Toàn bộ dữ liệu on-chain — bao gồm: nội dung hợp đồng, deliverable hash, bằng chứng IPFS, lịch sử bỏ phiếu của Hội đồng trọng tài, và kết quả thực thi — có giá trị làm bằng chứng số trong quá trình giải quyết tại tòa án.
* Bằng việc ký kết trên nền tảng, cả hai bên đồng ý rằng: quyết định của Hội đồng trọng tài là cơ chế ưu tiên; nếu tiếp tục khiếu nại qua pháp lý, mọi chi phí pháp lý phát sinh do bên khởi kiện tự chịu.

## **Điều 20. Bằng chứng tranh chấp**

* Các bên upload lên IPFS, gọi submitEvidence(jobId, bytes32 ipfsHash) — hash CID (bytes32) on-chain.
* Giai đoạn initial: 0 → 72h kể từ khi mở tranh chấp.
* Giai đoạn rebuttal: 72h → 120h — các bên bổ sung phản hồi (48h).
* Sau 120h: không nhận bằng chứng mới on-chain.
* Đánh giá tính hợp lệ: do Hội đồng Arbitrator thực hiện off-chain khi xem IPFS; smart contract chỉ lưu hash và timestamp.
* Hành vi cố ý nộp bằng chứng giả mạo: bên vi phạm bị trừ Reputation Score và ghi nhận vi phạm off-chain.

## **Điều 21. Đóng băng tài sản**

* Khi raiseDispute() được gọi: trạng thái chuyển SUBMITTED hoặc IN\_PROGRESS → DISPUTED, toàn bộ tiền ký quỹ bị đóng băng trong EscrowVault.
* Không bên nào được nhận tiền cho đến khi có quyết định cuối cùng.
* Trường hợp tranh chấp hết hạn mà không có quyết định (lỗi hệ thống, thiếu Arbitrator): tiền tiếp tục đóng băng cho đến khi Platform Admin xử lý thủ công có ghi log minh bạch on-chain.

## **Điều 22. Cơ chế trọng tài (Kleros-inspired)**

**22.1 Thành lập hội đồng Arbitrator:**

* Tranh chấp được giải quyết bởi Hội đồng trọng tài (Arbitrator Panel) được chọn ngẫu nhiên từ pool Arbitrator.
* Điều kiện để trở thành Arbitrator:
  + Stake tối thiểu 50 USDC vào PlatformTreasury (stakeAsArbitrator).
  + Reputation Score >= 80 (Normal User trở lên).
  + Gọi joinPool() để vào pool — có thể leavePool() khi không còn dispute active.
  + Không là Client hoặc Freelancer của hợp đồng đang tranh chấp.
* Mỗi vụ tranh chấp được chỉ định 05 Arbitrator.

**22.2 Xung đột lợi ích (on-chain):**

* Arbitrator bị loại tự động nếu:
  + Là Client hoặc Freelancer của hợp đồng đang tranh chấp.
  + Đã tham gia vòng trọng tài trước đó của cùng hợp đồng (khi kháng cáo — hội đồng mới hoàn toàn).
  + Quan hệ hợp đồng 90 ngày / tranh chấp lặp 180 ngày: theo dõi off-chain trong phiên bản MVP (chưa enforce on-chain).

**22.3 Quy trình bỏ phiếu (commit-reveal như Kleros):**

|  |  |  |
| --- | --- | --- |
| **Giai đoạn** | **Thời gian (từ lúc mở vòng)** | **Hành động** |
| Evidence initial | 0 → 72h | Các bên submitEvidence() |
| Evidence rebuttal | 72h → 120h | Bổ sung bằng chứng / phản hồi |
| Commit | 120h → 144h | Arbitrator commitVote(jobId, hash(vote,salt)) |
| Reveal | 144h → 168h | Arbitrator revealVote(jobId, vote, salt) |

* Arbitrator không reveal: tự động slash khi finalizeDisputeVoting() (hoặc slashNoReveal() sau 168h) — 5 USDC stake + 10 điểm Reputation.

**✔ ĐÃ SỬA:** FIX 3 — Quorum fail: finalizeDisputeVoting() revert với InsufficientQuorum (< 3 phiếu hợp lệ). Trong MVP, Admin gọi adminForceResolve(jobId, decision) để giải quyết thủ công — Admin phải ghi log lý do off-chain trước khi gọi. Kết quả được emit AdminForceResolved event on-chain để đảm bảo tính minh bạch.

**22.4 Kết quả:**

* Kết quả: đa số trên 50% số phiếu hợp lệ (FREELANCER\_WIN / CLIENT\_WIN / SPLIT\_50\_50).
* Arbitrator vote đúng: nhận thưởng từ 50% Dispute Fee — chỉ áp dụng khi có bên rõ ràng thắng/thua (FREELANCER\_WIN hoặc CLIENT\_WIN).

**✔ ĐÃ SỬA:** FIX 4 — SPLIT không thưởng Arbitrator: khi kết quả là SPLIT\_50\_50, không có 'bên thua chịu phí' nên không có nguồn trả thưởng. 50% Dispute Fee hoàn cho bên khởi tạo, 50% còn lại vào Treasury làm quỹ vận hành — Arbitrator không nhận thưởng trong trường hợp này.

* Sau finalize vòng 1: cửa sổ kháng cáo 72h trước khi executeArbitrationResult().

**22.5 Kháng cáo:**

* Client hoặc Freelancer gọi fileAppeal() trong 72 giờ sau finalizeDisputeVoting() vòng 1.
* Appeal Fee = 1.3× Dispute Fee ban đầu.
* Hội đồng kháng cáo: 05 Arbitrator mới (startAppealRound) — không có thành viên vòng 1.
* Quy trình evidence/commit/reveal lặp lại cho vòng 2.
* Sau finalize vòng 2: executeArbitrationResult() — quyết định cuối cùng, không kháng cáo thêm.

**Lưu ý:** Điều kiện kháng cáo hợp lệ (bằng chứng mới / thông đồng Arbitrator) được kiểm tra off-chain bởi Admin. Contract chỉ enforce phí + thời hạn — không thể kiểm tra nội dung bằng chứng on-chain.

## **Điều 23. Kết quả tranh chấp**

* Freelancer thắng: nhận toàn bộ tiền ký quỹ + hoàn 100% Dispute Fee (nếu Freelancer là bên khởi tạo tranh chấp).
* Client thắng: nhận hoàn tiền ký quỹ toàn bộ + hoàn 100% Dispute Fee (nếu Client là bên khởi tạo).
* Phân chia (SPLIT\_50\_50): tiền ký quỹ chia 50/50; Dispute Fee hoàn 50% cho bên khởi tạo, 50% còn lại vào Treasury — Arbitrator không nhận thưởng (xem Điều 22.4).
* Thực thi: sau cửa sổ kháng cáo (hoặc sau vòng 2), gọi executeArbitrationResult() — release/refund/split tự động.
* Mỗi hợp đồng chỉ raiseDispute() một lần; kháng cáo tối đa một lần qua fileAppeal().

# **PHẦN VI: QUY ĐỊNH PHÍ NỀN TẢNG**

## **Điều 24. Phí nền tảng — Client (Platform Fee)**

* Phí nền tảng phía Client được thu tự động trên mỗi giao dịch releaseFunds() thành công (hợp đồng chuyển sang trạng thái COMPLETED).
* Fee Rate mặc định: 3% tính trên Contract Value.
* Công thức:
  + Platform Fee = Contract Value × 3%
  + Total Deposit (Client nạp) = Contract Value × 1.03
  + Freelancer nhận (gross) = Contract Value (trước khi trừ Service Fee theo Điều 25)
* Ví dụ: Hợp đồng 500 USDC → Client nạp 515 USDC → Platform thu 15 USDC từ phần Client.
* Toàn bộ Platform Fee chuyển tự động vào PlatformTreasury tại thời điểm releaseFunds().
* Trường hợp REFUNDED (Client thắng tranh chấp): Platform Fee không được thu; toàn bộ 103% Client đã nạp được hoàn trả.
* Trường hợp SPLIT: Platform Fee thu tương ứng trên phần giải ngân cho Freelancer (Freelancer nhận 50% → Platform thu 3% × 50% Contract Value từ phần Client).

## **Điều 25. Phí nền tảng — Freelancer (Service Fee)**

* Freelancer chịu phí dịch vụ trên mỗi lần nhận thanh toán thành công qua releaseFunds().
* Fee Rate mặc định: 2% tính trên số tiền Freelancer thực nhận.
* Công thức:
  + Service Fee = Contract Value × 2%
  + Freelancer thực nhận (net) = Contract Value × 0.98
* Ví dụ: Hợp đồng 500 USDC → Freelancer thực nhận 490 USDC → Platform thu thêm 10 USDC từ phần Freelancer.
* Tổng phí nền tảng trên mỗi hợp đồng hoàn thành: 3% (Client) + 2% (Freelancer) = 5% Contract Value.
* Trường hợp REFUNDED: Service Fee không được thu — Freelancer không nhận tiền nên không phát sinh phí.
* Trường hợp SPLIT: Service Fee chỉ thu trên phần Freelancer thực nhận.

|  |  |  |
| --- | --- | --- |
|  | **Client nạp** | **Freelancer nhận (net)** |
| Hợp đồng 500 USDC, COMPLETED | 515 USDC | 490 USDC |
| Platform nhận tổng | 15 + 10 = 25 USDC (5%) |  |

## **Điều 26. Phí tranh chấp (Dispute Fee)**

* Bên khởi tạo tranh chấp phải tạm ứng Dispute Fee.
* Công thức: Dispute Fee = Min(Contract Value × 2%, 50 USDC).
* Ví dụ: Hợp đồng 500 USDC → Dispute Fee = 10 USDC. Hợp đồng 10.000 USDC → Dispute Fee = 50 USDC.
* Sau khi Hội đồng trọng tài phán quyết: bên thắng được hoàn 100% Dispute Fee, bên thua chịu toàn bộ.
* Trường hợp SPLIT: Dispute Fee hoàn 50% cho bên khởi tạo, 50% còn lại vào Treasury (không thưởng Arbitrator).
* Hành vi lạm dụng cơ chế tranh chấp: mất Dispute Fee + giảm Reputation Score + hạn chế quyền sử dụng.

## **Điều 27. Quỹ Treasury**

**Nguồn thu vào:**

|  |  |  |
| --- | --- | --- |
| **Nguồn** | **Công thức** | **Điều kiện** |
| Platform Fee (Client) | 3% Contract Value | Khi COMPLETED |
| Service Fee (Freelancer) | 2% Contract Value | Khi COMPLETED |
| Dispute Fee (bên thua) | Theo Điều 26 | Sau phán quyết Hội đồng trọng tài |
| 50% Dispute Fee (SPLIT) | 50% của Dispute Fee | Sau kết quả SPLIT — không có bên thua rõ ràng |
| Penalty Fee | Khấu trừ Stake Arbitrator vi phạm | Khi có hành vi gian lận |

**Nguồn chi ra và tỷ lệ phân bổ:**

|  |  |  |
| --- | --- | --- |
| **Mục chi** | **Tỷ lệ** | **Mô tả** |
| Thưởng Arbitrator Panel | 50% Dispute Fee (WIN/LOSE) | Trả cho Arbitrator vote đúng kết quả — chỉ khi có bên thắng/thua rõ ràng |
| Vận hành hệ thống | 30% tổng thu | Hạ tầng, gas subsidize, bảo trì |
| Quỹ dự phòng | 20% tổng thu | Tối thiểu duy trì 5.000 USDC; chỉ dùng khi sự cố nghiêm trọng |
| Kiểm toán & nâng cấp | Phần còn lại | Audit định kỳ, phát triển tính năng mới |

**Nguyên tắc quản lý:**

* On-chain: PlatformTreasury ghi nhận totalPlatformFees (phí nền tảng) và totalReserveFund (slash stake Arbitrator). Phân bổ 30%/20% vận hành/dự phòng là chính sách off-chain — chưa tự động hóa trong smart contract MVP.
* Toàn bộ giao dịch vào/ra Treasury được ghi on-chain minh bạch, bất kỳ ai cũng có thể kiểm tra.
* Khoản chi > 1.000 USDC phải được Admin Multisig (3/5) phê duyệt trước khi thực thi (off-chain governance).
* Treasury và EscrowVault là hai smart contract tách biệt hoàn toàn — không bao giờ dùng Treasury để bù tiền ký quỹ hợp đồng.

*Luồng tiền:* Client nạp USDC → EscrowVault → approveAndRelease() / executeArbitrationResult() → Freelancer (net) + PlatformTreasury (Platform Fee + Service Fee + Dispute Fee phần thua)

# **PHẦN VII: REPUTATION SCORE**

## **Điều 28. Cơ chế Reputation Score**

* Mỗi người dùng được gán Reputation Score, lưu on-chain trong ReputationStore contract — không thể xóa hay giả mạo.

|  |  |  |
| --- | --- | --- |
| **Ngưỡng điểm** | **Mức độ** | **Quyền lợi / Hạn chế** |
| >= 120 điểm | Trusted User | Ưu tiên hiển thị (off-chain), giảm phí (chưa enforce on-chain — MVP dùng flat 3%/2%), đủ điều kiện Arbitrator Panel nếu stake đủ |
| 80 – 119 điểm | Normal User | Đủ điều kiện tham gia Arbitrator Panel (nếu stake đủ) |
| 50 – 79 điểm | Warning | Không gửi Proposal; không mở tranh chấp mới (on-chain) |
| < 50 điểm | Restricted User | Bị hạn chế nghiêm trọng, có thể bị khóa tài khoản |

## **Điều 29. Cập nhật Reputation Score**

* Score mặc định 100 điểm (chưa khởi tạo on-chain). Admin có thể điều chỉnh thủ công qua ReputationStore (authorizedContracts).

**Cập nhật tự động on-chain (EscrowVault / ArbitratorPanel):**

| Sự kiện | Freelancer | Client | Arbitrator |
| --- | --- | --- | --- |
| Hợp đồng COMPLETED (happy path / FL thắng / SPLIT) | +10 | +5 | — |
| Client thắng tranh chấp (REFUNDED) | −15 | +5 | — |
| Commit vote nhưng không reveal (slash) | — | — | −10 |

* Các tiêu chí khác (trễ hạn, đánh giá tích cực/tiêu cực, gian lận) do Admin cập nhật off-chain hoặc phiên bản sau.

**Freelancer được cộng điểm khi (off-chain / tương lai):**

* Hoàn thành công việc đúng hạn.
* Được Client nghiệm thu thành công.
* Nhận đánh giá tích cực.
* Thắng tranh chấp hợp lệ.

**Freelancer bị trừ điểm khi:**

* Trễ hạn bàn giao.
* Không hoàn thành công việc.
* Bị xác định vi phạm trong tranh chấp.
* Có hành vi gian lận.

**Client được cộng điểm khi:**

* Thanh toán đúng quy định.
* Nghiệm thu đúng thời hạn.
* Được Freelancer đánh giá tích cực.

**Client bị trừ điểm khi:**

* Từ chối thanh toán không có căn cứ.
* Cố tình trì hoãn nghiệm thu.
* Lạm dụng cơ chế tranh chấp.
* Có hành vi gian lận.

---

## **Phụ lục A — Đối chiếu luồng với marketplace (Upwork/Fiverr/Freelancer)**

| Bước | Chuẩn marketplace | On-chain MVP | Trạng thái |
|------|-------------------|--------------|------------|
| Đăng job | Client đăng mô tả + ngân sách | createJob() → OPEN | ✔ |
| Nhận bid/proposal | Freelancer gửi proposal | submitProposal() | ✔ |
| Thuê/chọn FL | Client chọn proposal | depositEscrow(jobId, freelancer) — client truyền địa chỉ FL (UI map từ proposal) | ✔ (off-chain chọn) |
| Ký quỹ | Escrow giữ tiền | depositEscrow — 103% USDC | ✔ |
| Bắt đầu làm | FL accept trong 72h | startWork() | ✔ |
| Giao hàng | Nộp deliverable | submitWork() + IPFS CID on-chain | ✔ |
| Nghiệm thu | Client approve / auto 7 ngày | approveAndRelease() / claimTimeoutRelease() | ✔ |
| Tranh chấp | Mediation/arbitration | raiseDispute → commit-reveal vote → executeArbitrationResult | ✔ |
| Reputation | Rating | ReputationStore tiers + auto score | ✔ |
| Phí nền tảng | Service fee | 3% client + 2% freelancer | ✔ |
| Minh bạch | Opaque backend | State machine + events + AdminTransferred | ✔ |

**Gap nhỏ (chấp nhận MVP):** Không có hàm acceptProposal(index) on-chain — client chọn freelancer qua địa chỉ ví khi deposit; frontend/backend liên kết proposal ↔ address. Không có messaging/revision rounds on-chain (theo thiết kế — off-chain).
