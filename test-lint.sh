#!/bin/bash

# Test script to verify flake8 configuration
echo "🧪 Testing flake8 configuration..."

# Install flake8 if not present
if ! command -v flake8 &> /dev/null; then
    echo "Installing flake8..."
    pip install flake8
fi

# Run flake8 with our configuration
echo "Running flake8..."
flake8 . --count --show-source --statistics

if [ $? -eq 0 ]; then
    echo "✅ All Python files pass linting!"
else
    echo "❌ Linting errors found. Please fix them before pushing."
    exit 1
fi