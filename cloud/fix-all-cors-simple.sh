#!/bin/bash

# Script đơn giản để fix CORS cho tất cả services - cho phép mọi origin
# Sử dụng: ./fix-all-cors-simple.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN_DIR="${SCRIPT_DIR}/server/api/gen/http"

echo "=========================================="
echo "Fixing CORS for all services"
echo "=========================================="
echo ""

# Tìm tất cả các file server.go có hàm handle*Origin
find "${GEN_DIR}" -type f -name "server.go" | while read file; do
    if ! grep -q "func handle.*Origin" "$file"; then
        continue
    fi
    
    service_name=$(echo "$file" | sed -E 's|.*/([^/]+)/server/server.go|\1|')
    
    # Kiểm tra xem đã được fix chưa
    if grep -q "Allow all origins" "$file"; then
        echo "✅ $service_name: Already fixed"
        continue
    fi
    
    # Tìm dòng có "if origin == \"\""
    origin_empty_line=$(grep -n "if origin == \"\"" "$file" | head -1 | cut -d: -f1)
    
    if [ -z "$origin_empty_line" ]; then
        echo "⚠️  $service_name: Could not find origin check"
        continue
    fi
    
    # Tìm dòng return sau đó
    return_line=$(sed -n "$((origin_empty_line + 1)),$"p "$file" | grep -n "^[[:space:]]*return" | head -1 | cut -d: -f1)
    
    if [ -z "$return_line" ]; then
        echo "⚠️  $service_name: Could not find return statement"
        continue
    fi
    
    insert_line=$((origin_empty_line + return_line))
    
    # Tạo code để insert
    cat > /tmp/cors_insert.txt << 'EOF'
		// Allow all origins (for development/staging)
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Vary", "Origin")
		w.Header().Set("Access-Control-Expose-Headers", "Authorization, Content-Type")
		w.Header().Set("Access-Control-Max-Age", "86400")
		w.Header().Set("Access-Control-Allow-Credentials", "false")
		if acrm := r.Header.Get("Access-Control-Request-Method"); acrm != "" {
			w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS, POST, DELETE, PATCH, PUT")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type")
		}
		origHndlr(w, r)
		return
EOF
    
    # Insert code
    sed -i.bak "${insert_line}r /tmp/cors_insert.txt" "$file"
    rm -f "${file}.bak"
    
    echo "✅ $service_name: Fixed"
done

rm -f /tmp/cors_insert.txt

echo ""
echo "=========================================="
echo "✅ Done! All services now allow all CORS origins"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This allows ALL origins. For production, restrict origins."
echo ""

