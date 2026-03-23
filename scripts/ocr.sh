#!/bin/bash

# OCR Skill Script - 小爪文字识别工具
# 支持图片(JPG/PNG)和PDF文件的文字识别

set -e

print_usage() {
    echo "用法: $0 <文件路径> [语言选项]"
    echo "  文件路径: 要识别的图片或PDF文件路径"
    echo "  语言选项: 可选, zh (中文), en (英文), 或 zh+en (中英文混合)"
    echo "  默认使用中英文混合识别"
}

# 检查参数
if [ $# -lt 1 ]; then
    echo "错误: 请提供文件路径"
    print_usage
    exit 1
fi

INPUT_FILE="$1"
LANG_OPTION="${2:-chi_sim+eng}"

# 将用户友好的语言选项转换为Tesseract语言代码
case "$LANG_OPTION" in
    zh)    LANG_OPTION="chi_sim" ;;
    en)    LANG_OPTION="eng" ;;
    zh+en) LANG_OPTION="chi_sim+eng" ;;
esac

# 验证文件存在
if [ ! -f "$INPUT_FILE" ]; then
    echo "错误: 文件不存在 - $INPUT_FILE"
    exit 1
fi

# 检查文件类型（统一转为大写用于判断，小写用于保存）
FILE_EXT=$(echo "$INPUT_FILE" | awk -F. '{print $NF}' | tr '[:lower:]' '[:upper:]')
FILE_EXT_LOWER=$(echo "$FILE_EXT" | tr '[:upper:]' '[:lower:]')

echo "=== 小爪OCR识别开始 ==="
echo "输入文件: $INPUT_FILE"
echo "文件类型: $FILE_EXT"
echo "识别语言: $LANG_OPTION"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "临时工作目录: $TEMP_DIR"

# 处理不同文件类型
if [[ "$FILE_EXT" == "PDF" ]]; then
    echo "正在处理PDF文件..."
    # 使用pdfimages提取图片（如果PDF包含扫描图像）
    if command -v pdfimages >/dev/null 2>&1; then
        IMAGE_COUNT=$(pdfimages -list "$INPUT_FILE" 2>/dev/null | tail -n +3 | wc -l)
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            echo "PDF中检测到 $IMAGE_COUNT 张图像，将进行图像OCR识别"
            # 将PDF转为PNG序列
            convert -density 300 "$INPUT_FILE" "$TEMP_DIR/page-%03d.png" 2>/dev/null || true
        else
            echo "PDF是文本型，尝试直接提取文本"
            pdftotext "$INPUT_FILE" "$TEMP_DIR/extracted.txt" 2>/dev/null || true
            if [ -s "$TEMP_DIR/extracted.txt" ]; then
                echo "成功提取PDF文本内容："
                echo "--- 提取的文本 ---"
                cat "$TEMP_DIR/extracted.txt"
                echo "--- 结束 ---"
                exit 0
            fi
        fi
    else
        echo "警告: pdfimages未安装，将直接尝试OCR识别整个PDF"
        convert -density 300 "$INPUT_FILE" "$TEMP_DIR/page-%03d.png" 2>/dev/null || true
    fi
elif [[ "$FILE_EXT" == "JPG" || "$FILE_EXT" == "JPEG" || "$FILE_EXT" == "PNG" || "$FILE_EXT" == "GIF" || "$FILE_EXT" == "WEBP" ]]; then
    echo "正在处理图片文件..."
    cp "$INPUT_FILE" "$TEMP_DIR/input.$FILE_EXT_LOWER"
else
    echo "错误: 不支持的文件格式 - $FILE_EXT"
    exit 1
fi

# 执行OCR识别
echo "正在执行OCR识别..."

# 查找所有图片文件（启用nullglob避免未匹配的glob模式作为字面量进入数组）
# 搜索全部扩展名：PDF转换输出固定为.png，图片文件复制时使用原始小写扩展名
shopt -s nullglob
IMAGE_FILES=($TEMP_DIR/*.png $TEMP_DIR/*.jpg $TEMP_DIR/*.jpeg $TEMP_DIR/*.gif $TEMP_DIR/*.webp)
shopt -u nullglob

if [ ${#IMAGE_FILES[@]} -eq 0 ]; then
    echo "错误: 未找到可处理的图像文件"
    exit 1
fi

# 对每个图像文件执行OCR
OUTPUT_FILE="$TEMP_DIR/ocr_result.txt"
> "$OUTPUT_FILE"

PAGE_NUM=1
for IMG_FILE in "${IMAGE_FILES[@]}"; do
    if [ -f "$IMG_FILE" ]; then
        echo "  处理第 $PAGE_NUM 页..."
        
        # 预处理图像以提高OCR准确率
        if command -v convert >/dev/null 2>&1; then
            PREPROCESSED="$TEMP_DIR/processed_$(basename "$IMG_FILE")"
            # 调整对比度、锐化、二值化
            convert "$IMG_FILE" \
                -contrast-stretch 5%x5% \
                -sharpen 0x1 \
                -threshold 60% \
                "$PREPROCESSED"
            
            if [ -s "$PREPROCESSED" ]; then
                IMG_FILE="$PREPROCESSED"
            fi
        fi
        
        # 执行Tesseract OCR
        if command -v tesseract >/dev/null 2>&1; then
            tesseract "$IMG_FILE" stdout -l "$LANG_OPTION" --psm 3 2>/dev/null >> "$OUTPUT_FILE" || true
        else
            echo "错误: Tesseract OCR未安装。请运行: sudo apt-get install tesseract-ocr tesseract-ocr-chi-sim tesseract-ocr-eng" >> "$OUTPUT_FILE"
            echo "或者: brew install tesseract tesseract-lang" >> "$OUTPUT_FILE"
            break
        fi
        
        PAGE_NUM=$((PAGE_NUM + 1))
    fi
done

# 输出结果
if [ -s "$OUTPUT_FILE" ]; then
    echo "=== OCR识别完成 ==="
    echo "识别结果："
    echo "--- 识别文本 ---"
    cat "$OUTPUT_FILE"
    echo "--- 结束 ---"
    
    # 统计信息
    WORD_COUNT=$(cat "$OUTPUT_FILE" | wc -w)
    LINE_COUNT=$(cat "$OUTPUT_FILE" | wc -l)
    echo "统计信息: $WORD_COUNT 个词, $LINE_COUNT 行"
else
    echo "=== OCR识别完成 ==="
    echo "警告: 未识别到任何文字内容"
    echo "可能原因:"
    echo "- 图像质量较差（模糊、倾斜、低对比度）"
    echo "- 文字太小或字体特殊"
    echo "- 语言模型不匹配"
    echo "- 文件为空或损坏"
fi
