#!/bin/bash

# OCR Skill Script - 小爪文字识别工具
# 支持图片(JPG/PNG)和PDF文件的文字识别

set -e

print_usage() {
    echo "用法: $0 --input <文件路径> [--lang <语言选项>]"
    echo "  或:  $0 <文件路径> [语言选项]"
    echo "  选项: --plain  只输出识别文本，适合模型调用"
    echo "  文件路径: 要识别的图片或PDF文件路径"
    echo "  语言选项: 可选, zh (中文), en (英文), 或 zh+en (中英文混合)"
    echo "  默认使用中英文混合识别"
}

# 解析参数，兼容命名参数和旧的位置参数
INPUT_FILE=""
LANG_OPTION="chi_sim+eng"
PLAIN_OUTPUT=0

print_info() {
    if [ "$PLAIN_OUTPUT" -eq 0 ]; then
        echo "$1"
    fi
}

print_error() {
    echo "$1" >&2
}

die() {
    print_error "$1"
    exit 1
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --input|-i)
            if [ -z "$2" ]; then
                print_error "错误: --input 需要提供文件路径"
                print_usage
                exit 1
            fi
            INPUT_FILE="$2"
            shift 2
            ;;
        --lang|-l)
            if [ -z "$2" ]; then
                print_error "错误: --lang 需要提供语言选项"
                print_usage
                exit 1
            fi
            LANG_OPTION="$2"
            shift 2
            ;;
        --plain)
            PLAIN_OUTPUT=1
            shift
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        --*)
            print_error "错误: 不支持的参数 - $1"
            print_usage
            exit 1
            ;;
        *)
            if [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            elif [ "$LANG_OPTION" = "chi_sim+eng" ]; then
                LANG_OPTION="$1"
            else
                print_error "错误: 多余的参数 - $1"
                print_usage
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$INPUT_FILE" ]; then
    print_error "错误: 请提供文件路径"
    print_usage
    exit 1
fi

# 将用户友好的语言选项转换为Tesseract语言代码
case "$LANG_OPTION" in
    zh)    LANG_OPTION="chi_sim" ;;
    en)    LANG_OPTION="eng" ;;
    zh+en) LANG_OPTION="chi_sim+eng" ;;
esac

# 验证文件存在
if [ ! -f "$INPUT_FILE" ]; then
    die "错误: 文件不存在 - $INPUT_FILE"
fi

# 检查文件类型（统一转为大写用于判断，小写用于保存）
FILE_EXT=$(echo "$INPUT_FILE" | awk -F. '{print $NF}' | tr '[:lower:]' '[:upper:]')
FILE_EXT_LOWER=$(echo "$FILE_EXT" | tr '[:upper:]' '[:lower:]')

print_info "=== 小爪OCR识别开始 ==="
print_info "输入文件: $INPUT_FILE"
print_info "文件类型: $FILE_EXT"
print_info "识别语言: $LANG_OPTION"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

print_info "临时工作目录: $TEMP_DIR"

# 处理不同文件类型
if [[ "$FILE_EXT" == "PDF" ]]; then
    print_info "正在处理PDF文件..."
    # 使用pdfimages提取图片（如果PDF包含扫描图像）
    if has_command pdfimages; then
        IMAGE_COUNT=$(pdfimages -list "$INPUT_FILE" 2>/dev/null | tail -n +3 | wc -l)
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            print_info "PDF中检测到 $IMAGE_COUNT 张图像，将进行图像OCR识别"
            # 将PDF转为PNG序列
            if has_command convert; then
                convert -density 300 "$INPUT_FILE" "$TEMP_DIR/page-%03d.png" 2>/dev/null || true
            else
                die "错误: 处理扫描版PDF需要 ImageMagick 的 convert 命令"
            fi
        else
            print_info "PDF是文本型，尝试直接提取文本"
            if ! has_command pdftotext; then
                die "错误: 提取文本型PDF需要 pdftotext 命令"
            fi

            pdftotext "$INPUT_FILE" "$TEMP_DIR/extracted.txt" 2>/dev/null || true
            if [ -s "$TEMP_DIR/extracted.txt" ]; then
                if [ "$PLAIN_OUTPUT" -eq 0 ]; then
                    echo "成功提取PDF文本内容："
                    echo "--- 提取的文本 ---"
                    cat "$TEMP_DIR/extracted.txt"
                    echo "--- 结束 ---"
                else
                    cat "$TEMP_DIR/extracted.txt"
                fi
                exit 0
            fi

            if has_command convert; then
                print_info "未直接提取到文本，尝试转图片后进行OCR"
                convert -density 300 "$INPUT_FILE" "$TEMP_DIR/page-%03d.png" 2>/dev/null || true
            else
                die "错误: PDF未提取到文本，且缺少 convert 命令继续进行OCR"
            fi
        fi
    else
        print_info "警告: pdfimages未安装，将直接尝试OCR识别整个PDF"
        if has_command convert; then
            convert -density 300 "$INPUT_FILE" "$TEMP_DIR/page-%03d.png" 2>/dev/null || true
        else
            die "错误: 处理PDF需要 pdfimages 或 convert 命令"
        fi
    fi
elif [[ "$FILE_EXT" == "JPG" || "$FILE_EXT" == "JPEG" || "$FILE_EXT" == "PNG" || "$FILE_EXT" == "GIF" || "$FILE_EXT" == "WEBP" ]]; then
    print_info "正在处理图片文件..."
    cp "$INPUT_FILE" "$TEMP_DIR/input.$FILE_EXT_LOWER"
else
    die "错误: 不支持的文件格式 - $FILE_EXT"
fi

# 执行OCR识别
print_info "正在执行OCR识别..."

if ! has_command tesseract; then
    die "错误: Tesseract OCR未安装。请运行: sudo apt-get install tesseract-ocr tesseract-ocr-chi-sim tesseract-ocr-eng"
fi

# 查找所有图片文件（启用nullglob避免未匹配的glob模式作为字面量进入数组）
# 搜索全部扩展名：PDF转换输出固定为.png，图片文件复制时使用原始小写扩展名
shopt -s nullglob
IMAGE_FILES=($TEMP_DIR/*.png $TEMP_DIR/*.jpg $TEMP_DIR/*.jpeg $TEMP_DIR/*.gif $TEMP_DIR/*.webp)
shopt -u nullglob

if [ ${#IMAGE_FILES[@]} -eq 0 ]; then
    die "错误: 未找到可处理的图像文件"
fi

# 对每个图像文件执行OCR
OUTPUT_FILE="$TEMP_DIR/ocr_result.txt"
> "$OUTPUT_FILE"

PAGE_NUM=1
for IMG_FILE in "${IMAGE_FILES[@]}"; do
    if [ -f "$IMG_FILE" ]; then
        print_info "  处理第 $PAGE_NUM 页..."
        
        # 预处理图像以提高OCR准确率
        if has_command convert; then
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
        tesseract "$IMG_FILE" stdout -l "$LANG_OPTION" --psm 3 2>/dev/null >> "$OUTPUT_FILE" || true
        
        PAGE_NUM=$((PAGE_NUM + 1))
    fi
done

# 输出结果
if [ -s "$OUTPUT_FILE" ]; then
    if [ "$PLAIN_OUTPUT" -eq 0 ]; then
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
        cat "$OUTPUT_FILE"
    fi
else
    if [ "$PLAIN_OUTPUT" -eq 0 ]; then
        echo "=== OCR识别完成 ==="
        echo "警告: 未识别到任何文字内容"
        echo "可能原因:"
        echo "- 图像质量较差（模糊、倾斜、低对比度）"
        echo "- 文字太小或字体特殊"
        echo "- 语言模型不匹配"
        echo "- 文件为空或损坏"
    else
        print_error "错误: 未识别到任何文字内容"
        exit 1
    fi
fi
