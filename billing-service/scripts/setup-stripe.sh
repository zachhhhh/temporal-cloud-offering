#!/bin/bash
# Temporal Cloud - Stripe Product Setup
# Run this script to create products and prices in Stripe

set -e

# Check for Stripe CLI
if ! command -v stripe &> /dev/null; then
    echo "Stripe CLI not found. Install with: brew install stripe/stripe-cli/stripe"
    exit 1
fi

echo "=============================================="
echo "  Temporal Cloud - Stripe Setup"
echo "=============================================="
echo ""

# Create Products
echo "Creating products..."

# Essential Plan
ESSENTIAL_PRODUCT=$(stripe products create \
    --name="Temporal Cloud Essential" \
    --description="1M actions/month, 1GB active storage, 40GB retained storage" \
    --metadata[plan]="essential" \
    --format=json | jq -r '.id')
echo "Created Essential product: $ESSENTIAL_PRODUCT"

ESSENTIAL_PRICE=$(stripe prices create \
    --product="$ESSENTIAL_PRODUCT" \
    --unit-amount=10000 \
    --currency=usd \
    --recurring[interval]=month \
    --format=json | jq -r '.id')
echo "Created Essential price: $ESSENTIAL_PRICE"

# Business Plan
BUSINESS_PRODUCT=$(stripe products create \
    --name="Temporal Cloud Business" \
    --description="2.5M actions/month, 2.5GB active storage, 100GB retained storage" \
    --metadata[plan]="business" \
    --format=json | jq -r '.id')
echo "Created Business product: $BUSINESS_PRODUCT"

BUSINESS_PRICE=$(stripe prices create \
    --product="$BUSINESS_PRODUCT" \
    --unit-amount=50000 \
    --currency=usd \
    --recurring[interval]=month \
    --format=json | jq -r '.id')
echo "Created Business price: $BUSINESS_PRICE"

# Enterprise Plan (custom pricing - placeholder)
ENTERPRISE_PRODUCT=$(stripe products create \
    --name="Temporal Cloud Enterprise" \
    --description="10M+ actions/month, 10GB+ active storage, 400GB+ retained storage" \
    --metadata[plan]="enterprise" \
    --format=json | jq -r '.id')
echo "Created Enterprise product: $ENTERPRISE_PRODUCT"

# Metered usage products
echo ""
echo "Creating metered usage products..."

# Actions overage
ACTIONS_PRODUCT=$(stripe products create \
    --name="Temporal Cloud Actions Overage" \
    --description="Additional actions beyond plan limit" \
    --metadata[type]="usage" \
    --format=json | jq -r '.id')

ACTIONS_PRICE=$(stripe prices create \
    --product="$ACTIONS_PRODUCT" \
    --unit-amount=25 \
    --currency=usd \
    --recurring[interval]=month \
    --recurring[usage-type]=metered \
    --billing-scheme=per_unit \
    --format=json | jq -r '.id')
echo "Created Actions overage price: $ACTIONS_PRICE (per 1000 actions)"

# Active storage
ACTIVE_STORAGE_PRODUCT=$(stripe products create \
    --name="Temporal Cloud Active Storage" \
    --description="Active workflow storage" \
    --metadata[type]="usage" \
    --format=json | jq -r '.id')

ACTIVE_STORAGE_PRICE=$(stripe prices create \
    --product="$ACTIVE_STORAGE_PRODUCT" \
    --unit-amount-decimal="4.2" \
    --currency=usd \
    --recurring[interval]=month \
    --recurring[usage-type]=metered \
    --billing-scheme=per_unit \
    --format=json | jq -r '.id')
echo "Created Active storage price: $ACTIVE_STORAGE_PRICE (per GB-hour)"

# Retained storage
RETAINED_STORAGE_PRODUCT=$(stripe products create \
    --name="Temporal Cloud Retained Storage" \
    --description="Retained workflow history storage" \
    --metadata[type]="usage" \
    --format=json | jq -r '.id')

RETAINED_STORAGE_PRICE=$(stripe prices create \
    --product="$RETAINED_STORAGE_PRODUCT" \
    --unit-amount-decimal="0.105" \
    --currency=usd \
    --recurring[interval]=month \
    --recurring[usage-type]=metered \
    --billing-scheme=per_unit \
    --format=json | jq -r '.id')
echo "Created Retained storage price: $RETAINED_STORAGE_PRICE (per GB-hour)"

echo ""
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo ""
echo "Add these price IDs to your configuration:"
echo ""
echo "STRIPE_PRICE_ESSENTIAL=$ESSENTIAL_PRICE"
echo "STRIPE_PRICE_BUSINESS=$BUSINESS_PRICE"
echo "STRIPE_PRICE_ACTIONS=$ACTIONS_PRICE"
echo "STRIPE_PRICE_ACTIVE_STORAGE=$ACTIVE_STORAGE_PRICE"
echo "STRIPE_PRICE_RETAINED_STORAGE=$RETAINED_STORAGE_PRICE"
echo ""
echo "Create a webhook endpoint in Stripe Dashboard:"
echo "  URL: https://api.yourdomain.com/webhooks/stripe"
echo "  Events: invoice.paid, invoice.payment_failed, customer.subscription.updated"
echo ""
