# OCR技能使用指南

## 功能说明
这个技能用于从图片（JPG/PNG）和PDF文件中提取文字内容。

## 使用方法
1. 将图片或PDF文件发送给小爪
2. 小爪会自动识别并返回文字内容
3. 支持中英文混合识别

## 技术细节
- 使用Tesseract OCR引擎（v5+）
- 支持中文（chi_sim）和英文（eng）语言包
- 自动处理常见格式问题

## 注意事项
- 图片清晰度会影响识别准确率
- 手写体识别效果有限
- 复杂排版可能需要后期整理

## 测试命令
```bash
# 测试图片识别
./scripts/ocr.sh --input test.jpg --lang chi_sim+eng

# 测试PDF识别
./scripts/ocr.sh --input document.pdf --lang chi_sim+eng
```
