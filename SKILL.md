# OCR文字识别技能（最小执行版）

用途：从图片或 PDF 提取纯文本。

触发：用户要 OCR / 识别截图文字 / 提取 PDF 文字。

命令：
./scripts/ocr.sh --input <文件路径> --lang zh+en --plain

参数：
- --input 必填
- --lang 可选：zh | en | zh+en（默认 zh+en）
- --plain 必带

返回：
- 成功：直接返回 stdout 原文
- 失败：直接返回错误
- 未识别到文字：明确说明未识别到可用文本

限制：
- 不承诺置信度、JSON、Markdown 输出
- 不臆测未识别出的内容