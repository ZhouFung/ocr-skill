#!/usr/bin/env bats
# Tests for scripts/ocr.sh

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/scripts/ocr.sh"
FIXTURES="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/fixtures"
MOCKS="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/mocks"

setup() {
    # Prepend mocks to PATH so they override real tools during tests
    export PATH="$MOCKS:$PATH"
    # Reset PDF image count to a sensible default (1 image)
    export OCR_MOCK_PDF_IMAGE_COUNT=1
    # Temp resources created by individual tests; cleaned up in teardown
    TEST_TMPFILE=""
    TEST_TMPDIR=""
}

teardown() {
    [ -n "$TEST_TMPFILE" ] && rm -f "$TEST_TMPFILE"
    [ -n "$TEST_TMPDIR"  ] && rm -rf "$TEST_TMPDIR"
    return 0
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

@test "exits with error when no arguments are provided" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"错误: 请提供文件路径"* ]]
}

@test "prints usage when no arguments are provided" {
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"用法:"* ]]
}

# ---------------------------------------------------------------------------
# File existence check
# ---------------------------------------------------------------------------

@test "exits with error when file does not exist" {
    run bash "$SCRIPT" "/nonexistent/path/file.png"
    [ "$status" -eq 1 ]
    [[ "$output" == *"错误: 文件不存在"* ]]
}

@test "error message includes the missing filename" {
    run bash "$SCRIPT" "/tmp/does_not_exist_xyz.jpg"
    [ "$status" -eq 1 ]
    [[ "$output" == *"/tmp/does_not_exist_xyz.jpg"* ]]
}

# ---------------------------------------------------------------------------
# Unsupported file format
# ---------------------------------------------------------------------------

@test "exits with error for unsupported file extension" {
    run bash "$SCRIPT" "$FIXTURES/sample.txt"
    [ "$status" -eq 1 ]
    [[ "$output" == *"错误: 不支持的文件格式"* ]]
}

@test "error message includes the unsupported extension" {
    run bash "$SCRIPT" "$FIXTURES/sample.txt"
    [ "$status" -eq 1 ]
    [[ "$output" == *"TXT"* ]]
}

# ---------------------------------------------------------------------------
# Language option conversion
# ---------------------------------------------------------------------------

@test "converts zh language option to chi_sim" {
    run bash "$SCRIPT" "$FIXTURES/sample.png" "zh"
    [[ "$output" == *"chi_sim"* ]]
}

@test "converts en language option to eng" {
    run bash "$SCRIPT" "$FIXTURES/sample.png" "en"
    [[ "$output" == *"eng"* ]]
}

@test "converts zh+en language option to chi_sim+eng" {
    run bash "$SCRIPT" "$FIXTURES/sample.png" "zh+en"
    [[ "$output" == *"chi_sim+eng"* ]]
}

@test "uses chi_sim+eng as default language when none specified" {
    run bash "$SCRIPT" "$FIXTURES/sample.png"
    [[ "$output" == *"chi_sim+eng"* ]]
}

@test "supports --input named argument" {
    run bash "$SCRIPT" --input "$FIXTURES/sample.png"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PNG"* ]]
}

@test "supports --lang named argument" {
    run bash "$SCRIPT" --input "$FIXTURES/sample.png" --lang zh+en
    [ "$status" -eq 0 ]
    [[ "$output" == *"chi_sim+eng"* ]]
}

@test "supports --plain for image OCR" {
    run bash "$SCRIPT" --input "$FIXTURES/sample.png" --lang zh+en --plain
    [ "$status" -eq 0 ]
    [ "$output" = "Sample OCR text" ]
}

@test "supports --plain for text-based PDF OCR" {
    export OCR_MOCK_PDF_IMAGE_COUNT=0
    run bash "$SCRIPT" --input "$FIXTURES/sample.pdf" --lang zh+en --plain
    [ "$status" -eq 0 ]
    [ "$output" = "Extracted PDF text content" ]
}

@test "exits non-zero in plain mode when tesseract is missing" {
    TEST_TMPDIR="$(mktemp -d)"
    for cmd in awk basename bash cat cp mktemp rm tr wc; do
        ln -s "$(command -v "$cmd")" "$TEST_TMPDIR/$cmd"
    done
    run env PATH="$TEST_TMPDIR" bash "$SCRIPT" --input "$FIXTURES/sample.png" --plain
    [ "$status" -ne 0 ]
    [[ "$output" == *"Tesseract OCR未安装"* ]]
}

@test "exits non-zero for unsupported named option" {
    run bash "$SCRIPT" --bad-option
    [ "$status" -ne 0 ]
    [[ "$output" == *"不支持的参数"* ]]
}

@test "passes through unrecognised language codes unchanged" {
    run bash "$SCRIPT" "$FIXTURES/sample.png" "fra"
    [[ "$output" == *"fra"* ]]
}

# ---------------------------------------------------------------------------
# Image file processing
# ---------------------------------------------------------------------------

@test "successfully processes a PNG file" {
    run bash "$SCRIPT" "$FIXTURES/sample.png"
    [ "$status" -eq 0 ]
    [[ "$output" == *"小爪OCR识别开始"* ]]
    [[ "$output" == *"PNG"* ]]
}

@test "successfully processes a JPG file" {
    run bash "$SCRIPT" "$FIXTURES/sample.jpg"
    [ "$status" -eq 0 ]
    [[ "$output" == *"小爪OCR识别开始"* ]]
    [[ "$output" == *"JPG"* ]]
}

@test "successfully processes a JPEG file (copy with .jpeg extension)" {
    TEST_TMPFILE="$(mktemp --suffix=.jpeg)"
    cp "$FIXTURES/sample.jpg" "$TEST_TMPFILE"
    run bash "$SCRIPT" "$TEST_TMPFILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"JPEG"* ]]
}

@test "successfully processes a GIF file" {
    # Create a minimal GIF87a stub
    TEST_TMPFILE="$(mktemp --suffix=.gif)"
    printf 'GIF87a\x01\x00\x01\x00\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x44\x01\x00\x3b' > "$TEST_TMPFILE"
    run bash "$SCRIPT" "$TEST_TMPFILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GIF"* ]]
}

@test "successfully processes a WEBP file" {
    TEST_TMPFILE="$(mktemp --suffix=.webp)"
    cp "$FIXTURES/sample.png" "$TEST_TMPFILE"
    run bash "$SCRIPT" "$TEST_TMPFILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WEBP"* ]]
}

@test "image processing prints OCR start banner" {
    run bash "$SCRIPT" "$FIXTURES/sample.png"
    [[ "$output" == *"=== 小爪OCR识别开始 ==="* ]]
}

# ---------------------------------------------------------------------------
# OCR output
# ---------------------------------------------------------------------------

@test "shows OCR completion banner on success" {
    run bash "$SCRIPT" "$FIXTURES/sample.png"
    [ "$status" -eq 0 ]
    [[ "$output" == *"=== OCR识别完成 ==="* ]]
}

@test "displays extracted text delimiters on success" {
    run bash "$SCRIPT" "$FIXTURES/sample.png"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--- 识别文本 ---"* ]]
    [[ "$output" == *"--- 结束 ---"* ]]
}

@test "displays word and line count statistics on success" {
    run bash "$SCRIPT" "$FIXTURES/sample.png"
    [ "$status" -eq 0 ]
    [[ "$output" == *"统计信息:"* ]]
}

# ---------------------------------------------------------------------------
# PDF processing – image-based PDF
# ---------------------------------------------------------------------------

@test "successfully processes an image-based PDF" {
    export OCR_MOCK_PDF_IMAGE_COUNT=1
    run bash "$SCRIPT" "$FIXTURES/sample.pdf"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PDF"* ]]
    [[ "$output" == *"=== OCR识别完成 ==="* ]]
}

@test "reports detected image count for image-based PDF" {
    export OCR_MOCK_PDF_IMAGE_COUNT=3
    run bash "$SCRIPT" "$FIXTURES/sample.pdf"
    [ "$status" -eq 0 ]
    [[ "$output" == *"3 张图像"* ]]
}

# ---------------------------------------------------------------------------
# PDF processing – text-based PDF
# ---------------------------------------------------------------------------

@test "extracts text directly from a text-based PDF" {
    export OCR_MOCK_PDF_IMAGE_COUNT=0
    run bash "$SCRIPT" "$FIXTURES/sample.pdf"
    [ "$status" -eq 0 ]
    # pdftotext mock writes "Extracted PDF text content"
    [[ "$output" == *"Extracted PDF text content"* ]]
}

@test "exits 0 for text-based PDF extraction" {
    export OCR_MOCK_PDF_IMAGE_COUNT=0
    run bash "$SCRIPT" "$FIXTURES/sample.pdf"
    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Missing pdfimages – fallback behaviour
# ---------------------------------------------------------------------------

@test "falls back to direct convert when pdfimages is not installed" {
    NO_PDFIMAGES_PATH=$(echo "$PATH" | tr ':' '\n' | grep -v "$MOCKS" | tr '\n' ':' | sed 's/:$//')
    # Put back all mocks except pdfimages
    TEST_TMPDIR="$(mktemp -d)"
    cp "$MOCKS/tesseract" "$TEST_TMPDIR/"
    cp "$MOCKS/convert"   "$TEST_TMPDIR/"
    cp "$MOCKS/pdftotext" "$TEST_TMPDIR/"
    run env PATH="$TEST_TMPDIR:$NO_PDFIMAGES_PATH" bash "$SCRIPT" "$FIXTURES/sample.pdf"
    [[ "$output" == *"警告: pdfimages未安装"* ]]
}

# ---------------------------------------------------------------------------
# No image files found edge case
# ---------------------------------------------------------------------------

@test "exits with error when no image files are produced by convert" {
    # Mock convert that does nothing (produces no output files)
    TEST_TMPDIR="$(mktemp -d)"
    cat > "$TEST_TMPDIR/convert" << 'SCRIPT'
#!/bin/bash
# no-op: produce no output files
SCRIPT
    chmod +x "$TEST_TMPDIR/convert"
    # pdfimages still reports 1 image so we take the image-OCR branch
    export OCR_MOCK_PDF_IMAGE_COUNT=1
    run env PATH="$TEST_TMPDIR:$MOCKS:$(echo "$PATH" | tr ':' '\n' | grep -v "$MOCKS" | tr '\n' ':' | sed 's/:$//')" bash "$SCRIPT" "$FIXTURES/sample.pdf"
    [ "$status" -eq 1 ]
    [[ "$output" == *"错误: 未找到可处理的图像文件"* ]]
}

# ---------------------------------------------------------------------------
# Empty OCR result warning
# ---------------------------------------------------------------------------

@test "shows warning when tesseract produces no text" {
    # Mock tesseract that outputs nothing
    TEST_TMPDIR="$(mktemp -d)"
    printf '#!/bin/bash\n# outputs nothing\n' > "$TEST_TMPDIR/tesseract"
    chmod +x "$TEST_TMPDIR/tesseract"
    run env PATH="$TEST_TMPDIR:$MOCKS:$(echo "$PATH" | tr ':' '\n' | grep -v "$MOCKS" | tr '\n' ':' | sed 's/:$//')" bash "$SCRIPT" "$FIXTURES/sample.png"
    [ "$status" -eq 0 ]
    [[ "$output" == *"警告: 未识别到任何文字内容"* ]]
}
