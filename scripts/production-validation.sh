#!/bin/bash

echo "🎯 Fleet Manager Dashboard - Production Validation Suite"
echo "=========================================================="
echo ""

# Configuration
REPORT_FILE="validation-report-$(date +%Y%m%d_%H%M%S).md"
PASSED=0
FAILED=0
WARNINGS=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Start report
cat > $REPORT_FILE << EOF
# Production Validation Report

**Date:** $(date)
**Validator:** $USER
**Environment:** ${NODE_ENV:-development}

---

## Validation Results

EOF

log_result() {
    local status=$1
    local category=$2
    local test=$3
    local details=$4
    
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} [$category] $test"
        echo "✅ **PASS** - $test: $details" >> $REPORT_FILE
        ((PASSED++))
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗${NC} [$category] $test"
        echo "❌ **FAIL** - $test: $details" >> $REPORT_FILE
        ((FAILED++))
    else
        echo -e "${YELLOW}⚠${NC} [$category] $test"
        echo "⚠️ **WARNING** - $test: $details" >> $REPORT_FILE
        ((WARNINGS++))
    fi
}

# 1. Code Quality Checks
echo "1. Code Quality Validation"
echo "============================"
echo "" >> $REPORT_FILE
echo "### Code Quality" >> $REPORT_FILE
echo "" >> $REPORT_FILE

npm run type-check > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_result "PASS" "Code Quality" "TypeScript Compilation" "No type errors found"
else
    log_result "FAIL" "Code Quality" "TypeScript Compilation" "Type errors detected"
fi

npm run lint > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log_result "PASS" "Code Quality" "ESLint" "No linting errors"
else
    log_result "WARN" "Code Quality" "ESLint" "Linting warnings found"
fi

echo ""

# 2. Build Validation
echo "2. Build Validation"
echo "==================="
echo "" >> $REPORT_FILE
echo "### Build Process" >> $REPORT_FILE
echo "" >> $REPORT_FILE

BUILD_START=$(date +%s)
npm run build > /tmp/build.log 2>&1
BUILD_EXIT=$?
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

if [ $BUILD_EXIT -eq 0 ]; then
    log_result "PASS" "Build" "Production Build" "Build completed in ${BUILD_TIME}s"
else
    log_result "FAIL" "Build" "Production Build" "Build failed (see /tmp/build.log)"
fi

if [ -d ".next" ]; then
    BUILD_SIZE=$(du -sh .next | cut -f1)
    log_result "PASS" "Build" "Build Artifacts" "Build size: $BUILD_SIZE"
else
    log_result "FAIL" "Build" "Build Artifacts" "Build directory not found"
fi

echo ""

# 3. Dependency Security
echo "3. Security Validation"
echo "======================"
echo "" >> $REPORT_FILE
echo "### Security" >> $REPORT_FILE
echo "" >> $REPORT_FILE

npm audit --production --audit-level=high > /tmp/audit.log 2>&1
AUDIT_EXIT=$?
if [ $AUDIT_EXIT -eq 0 ]; then
    log_result "PASS" "Security" "Dependency Audit" "No high/critical vulnerabilities"
else
    log_result "WARN" "Security" "Dependency Audit" "Found vulnerabilities (see /tmp/audit.log)"
fi

# Check for exposed secrets
if grep -r "password\|secret\|api_key" .env.example > /dev/null 2>&1; then
    log_result "WARN" "Security" "Example Env File" "Contains sensitive key names"
else
    log_result "PASS" "Security" "Example Env File" "No sensitive data in example"
fi

echo ""

# 4. Environment Configuration
echo "4. Environment Configuration"
echo "============================"
echo "" >> $REPORT_FILE
echo "### Environment" >> $REPORT_FILE
echo "" >> $REPORT_FILE

REQUIRED_VARS=(
    "DATABASE_URL"
    "NEXT_PUBLIC_WS_URL"
    "NEXT_PUBLIC_MAP_STYLE_URL"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -n "${!var:-}" ]; then
        log_result "PASS" "Environment" "$var" "Variable is set"
    else
        log_result "FAIL" "Environment" "$var" "Variable is not set"
    fi
done

echo ""

# 5. Database Validation
echo "5. Database Validation"
echo "======================"
echo "" >> $REPORT_FILE
echo "### Database" >> $REPORT_FILE
echo "" >> $REPORT_FILE

if [ -n "${DATABASE_URL:-}" ]; then
    if command -v psql > /dev/null 2>&1; then
        psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_result "PASS" "Database" "Connection" "Database is reachable"
            # Check tables
            TABLE_COUNT=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null | xargs)
            if [ "${TABLE_COUNT:-0}" -gt 0 ]; then
                log_result "PASS" "Database" "Schema" "Found $TABLE_COUNT tables"
            else
                log_result "WARN" "Database" "Schema" "No tables found (migrations needed?)"
            fi
        else
            log_result "FAIL" "Database" "Connection" "Cannot connect to database"
        fi
    else
        log_result "WARN" "Database" "psql CLI" "psql not installed"
    fi
else
    log_result "WARN" "Database" "Configuration" "DATABASE_URL not set"
fi

echo ""

# 6. Redis Validation
echo "6. Redis Validation"
echo "==================="
echo "" >> $REPORT_FILE
echo "### Redis" >> $REPORT_FILE
echo "" >> $REPORT_FILE

if [ "${REDIS_ENABLED:-false}" = "true" ]; then
    if command -v redis-cli > "/dev/null" 2>&1; then
        if [ -n "${REDIS_URL:-}" ]; then
            redis-cli -u "$REDIS_URL" PING > /dev/null 2>&1
        else
            redis-cli PING > /dev/null 2>&1
        fi
        if [ $? -eq 0 ]; then
            log_result "PASS" "Redis" "Connection" "Redis is reachable"
        else
            log_result "FAIL" "Redis" "Connection" "Cannot connect to Redis"
        fi
    else
        log_result "WARN" "Redis" "CLI Tool" "redis-cli not installed"
    fi
else
    log_result "PASS" "Redis" "Configuration" "Redis disabled (using in-memory fallback)"
fi

echo ""

# 7. Documentation Validation
echo "7. Documentation Validation"
echo "==========================="
echo "" >> $REPORT_FILE
echo "### Documentation" >> $REPORT_FILE
echo "" >> $REPORT_FILE

REQUIRED_DOCS=(
    "README.md"
    "docs/ARCHITECTURE.md"
    "docs/API_DOCUMENTATION.md"
    "docs/PRODUCTION_DEPLOYMENT.md"
    "docs/FLEET_TESTING_GUIDE.md"
    "docs/OPERATIONS_RUNBOOK.md"
    "docs/FINAL_IMPLEMENTATION_SUMMARY.md"
    "docs/QUICK_START_PRODUCTION.md"
)

for doc in "${REQUIRED_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        WORD_COUNT=$(wc -w < "$doc")
        if [ "${WORD_COUNT:-0}" -gt 100 ]; then
            log_result "PASS" "Documentation" "$doc" "$WORD_COUNT words"
        else
            log_result "WARN" "Documentation" "$doc" "Document seems incomplete"
        fi
    else
        log_result "FAIL" "Documentation" "$doc" "File not found"
    fi
done

echo ""

# 8. Performance Benchmarks
echo "8. Performance Benchmarks"
echo "========================="
echo "" >> $REPORT_FILE
echo "### Performance" >> $REPORT_FILE
echo "" >> $REPORT_FILE

if [ -d ".next" ]; then
    if [ -d ".next/static" ]; then
        BUNDLE_SIZE=$(du -sh .next/static | cut -f1)
        log_result "PASS" "Performance" "Bundle Size" "Static assets: $BUNDLE_SIZE"
        LARGE_FILES=$(find .next/static -type f -size +1M | wc -n 2>/dev/null || find .next/static -type f -size +1M | wc -l)
        if [ "${LARGE_FILES:-0}" -eq 0 ]; then
            log_result "PASS" "Performance" "Asset Optimization" "No files >1MB"
        else
            log_result "WARN" "Performance" "Asset Optimization" "Found $LARGE_FILES files >1MB"
        fi
    else
        log_result "WARN" "Performance" "Bundle Size" ".next/static not found"
    fi
fi

echo ""

# 9. Deployment Readiness
echo "9. Deployment Readiness"
echo "======================="
echo "" >> $REPORT_FILE
echo "### Deployment" >> $REPORT_FILE
echo "" >> $REPORT_FILE

DEPLOYMENT_FILES=(
    "Dockerfile"
    "docker-compose.yml"
    ".dockerignore"
    "scripts/deploy-production.sh"
    "scripts/rollback.sh"
)

for file in "${DEPLOYMENT_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_result "PASS" "Deployment" "$file" "File exists"
    else
        log_result "WARN" "Deployment" "$file" "File not found"
    fi
done

echo ""

# 10. Monitoring Setup
echo "10. Monitoring Setup"
echo "===================="
echo "" >> $REPORT_FILE
echo "### Monitoring" >> $REPORT_FILE
echo "" >> $REPORT_FILE

MONITORING_FILES=(
    "prometheus.yml"
    "alerts.yml"
)

for file in "${MONITORING_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_result "PASS" "Monitoring" "$file" "Configuration exists"
    else
        log_result "WARN" "Monitoring" "$file" "Configuration not found (run setup-monitoring.sh)"
    fi
done

echo ""

# Generate Summary
echo "" >> $REPORT_FILE
echo "---" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "## Summary" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "- ✅ **Passed:** $PASSED" >> $REPORT_FILE
echo "- ❌ **Failed:** $FAILED" >> $REPORT_FILE
echo "- ⚠️ **Warnings:** $WARNINGS" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Overall Status
if [ $FAILED -eq 0 ]; then
    echo "## ✅ Overall Status: READY FOR PRODUCTION" >> $REPORT_FILE
    OVERALL_STATUS="READY"
else
    echo "## ❌ Overall Status: NOT READY (Fix failures above)" >> $REPORT_FILE
    OVERALL_STATUS="NOT READY"
fi

echo "" >> $REPORT_FILE
echo "---" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "**Report generated by:** production-validation.sh" >> $REPORT_FILE
echo "**Validation completed at:** $(date)" >> $REPORT_FILE

# Display Summary
echo ""
echo "=========================================================="
echo "Validation Summary"
echo "=========================================================="
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""
echo -e "Overall Status: ${BLUE}$OVERALL_STATUS${NC}"
echo ""
echo "📄 Full report saved to: $REPORT_FILE"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Production validation passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the validation report"
    echo "2. Address any warnings (optional)"
    echo "3. Proceed with deployment"
    exit 0
else
    echo -e "${RED}✗ Production validation failed!${NC}"
    echo ""
    echo "Please fix the failures before deploying to production."
    exit 1
fi
