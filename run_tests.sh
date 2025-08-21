#!/bin/bash

# Heads Up! Game - Test Runner Script
# This script runs all tests for the Flutter project

echo "========================================="
echo "     Heads Up! Game - Test Runner"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run tests and check results
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -e "${YELLOW}Running $test_name...${NC}"
    
    if eval $test_command; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        return 1
    fi
}

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

echo "1. Installing dependencies..."
flutter pub get

echo ""
echo "2. Generating mocks..."
dart run build_runner build --delete-conflicting-outputs

echo ""
echo "3. Running Unit Tests..."
echo "------------------------"

# Model tests
if run_test "Deck Model Tests" "flutter test test/models/deck_test.dart"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

if run_test "GameSession Model Tests" "flutter test test/models/game_session_test.dart"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

# Service tests
if run_test "AudioService Tests" "flutter test test/services/audio_service_test.dart"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

if run_test "HapticService Tests" "flutter test test/services/haptic_service_test.dart"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

echo ""
echo "4. Running Widget Tests..."
echo "--------------------------"

# Screen tests
if run_test "HomeScreen Tests" "flutter test test/screens/home_screen_test.dart"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

if run_test "GameplayScreen Tests" "flutter test test/screens/gameplay_screen_test.dart"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

# Main widget test
if run_test "Main App Tests" "flutter test test/widget_test.dart"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

echo ""
echo "5. Running All Tests Together..."
echo "--------------------------------"

if run_test "All Unit & Widget Tests" "flutter test"; then
    echo -e "${GREEN}All tests completed successfully!${NC}"
else
    echo -e "${YELLOW}Some tests may have issues. Check the output above.${NC}"
fi

echo ""
echo "6. Integration Tests (Optional)..."
echo "-----------------------------------"
echo "To run integration tests, use:"
echo "  flutter test integration_test/app_test.dart"
echo ""

echo "========================================="
echo "              TEST SUMMARY"
echo "========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please review the output above.${NC}"
    exit 1
fi

