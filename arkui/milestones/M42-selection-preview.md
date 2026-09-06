# M42 · 发送前查看所选文件

对照 Flutter `selected_files_page.dart`，为发送清单补上打开所选文件的入口。保留重命名和移除操作；系统查看使用原始 URI 与实际 MIME，即使发送名称改变扩展名也不会影响查看类型。打开操作不写入接收历史或修改选择。

验证：文件位置/查看与语言测试通过，覆盖媒体 URI、重命名后原始 MIME、只读 URI 授权和空 URI。ArkUI debug 构建通过。实际系统查看器交接待真机验收，未签名、未部署。

产物：`artifacts/AloeSend-2000042-M42-selection-preview-unsigned.hap`。
