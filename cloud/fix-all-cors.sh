#!/bin/bash

# Script để fix CORS cho tất cả services - cho phép mọi origin
# Sử dụng: ./fix-all-cors.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN_DIR="${SCRIPT_DIR}/server/api/gen/http"

echo "=========================================="
echo "Fixing CORS for all services"
echo "=========================================="
echo ""

# Tìm tất cả các file có handle*Origin
find "${GEN_DIR}" -type f -name "server.go" | while read file; do
    if grep -q "func handle.*Origin" "$file"; then
        service_name=$(echo "$file" | sed -E 's|.*/([^/]+)/server/server.go|\1|')
        echo "Processing: $service_name"
        
        # Kiểm tra xem đã được fix chưa
        if grep -q "Allow all origins" "$file"; then
            echo "  ✅ Already fixed"
            continue
        fi
        
        # Tìm dòng bắt đầu của hàm handle*Origin
        start_line=$(grep -n "func handle.*Origin" "$file" | head -1 | cut -d: -f1)
        
        if [ -z "$start_line" ]; then
            echo "  ⚠️  Could not find handle*Origin function"
            continue
        fi
        
        # Tìm dòng có "origin := r.Header.Get(\"Origin\")"
        origin_line=$(sed -n "${start_line},$"p "$file" | grep -n "origin := r.Header.Get" | head -1 | cut -d: -f1)
        
        if [ -z "$origin_line" ]; then
            echo "  ⚠️  Could not find origin header check"
            continue
        fi
        
        # Tính toán dòng thực tế
        actual_line=$((start_line + origin_line - 1))
        
        # Tìm dòng tiếp theo sau origin check (dòng có "if origin == \"\"")
        empty_check_line=$(sed -n "${actual_line},$"p "$file" | grep -n "if origin == \"\"" | head -1 | cut -d: -f1)
        
        if [ -z "$empty_check_line" ]; then
            echo "  ⚠️  Could not find empty origin check"
            continue
        fi
        
        # Tìm dòng return sau empty check
        return_line=$(sed -n "$((actual_line + empty_check_line - 1)),$"p "$file" | grep -n "return" | head -1 | cut -d: -f1)
        
        if [ -z "$return_line" ]; then
            echo "  ⚠️  Could not find return statement"
            continue
        fi
        
        insert_line=$((actual_line + empty_check_line + return_line))
        
        # Tạo patch để insert code
        cat > /tmp/cors_patch.txt << 'EOF'
		// Allow all origins (for development/staging)
		// TODO: Restrict this in production for security
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Vary", "Origin")
		w.Header().Set("Access-Control-Expose-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Max-Age", "86400")
		w.Header().Set("Access-Control-Allow-Credentials", "false")
		if acrm := r.Header.Get("Access-Control-Request-Method"); acrm != "" {
			// We are handling a preflight request
			w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS, POST, DELETE, PATCH, PUT")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		}
		origHndlr(w, r)
		return
EOF
        
        # Insert code vào file
        sed -i.bak "${insert_line}r /tmp/cors_patch.txt" "$file"
        
        echo "  ✅ Fixed"
    fi
done

echo ""
echo "=========================================="
echo "✅ Done! All services now allow all CORS origins"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This allows ALL origins. For production, you should:"
echo "   1. Regenerate code from design.go"
echo "   2. Or restrict origins based on environment variable"
echo ""

