# OCR技能使用指南

从图片或 PDF 提取纯文本。

## 调用
```bash
./scripts/ocr.sh --input <文件路径> --lang zh+en --plain
```

可选语言：`zh` / `en` / `zh+en`（默认 `zh+en`）

## 返回
- 成功：stdout 为识别文本
- 失败：返回错误信息，退出码非 0

## 测试

```bash
./scripts/test.sh
```
