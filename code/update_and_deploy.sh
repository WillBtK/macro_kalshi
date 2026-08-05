#!/bin/bash
# update_and_deploy.sh

# Run scraping
python3 kalshi_scraping/scrape_kalshi_trades.py

# Run R conversion
Rscript convert_trades_to_pdfs/data_convert_runner.R

# Sync data to cloud storage (example with AWS S3)
aws s3 sync ../data/daily_bid_ask_distribution_data s3://your-bucket/daily_bid_ask_distribution_data
aws s3 sync ../data/daily_bid_ask_moments_data s3://your-bucket/daily_bid_ask_moments_data
aws s3 sync ../data/daily_distribution_data s3://your-bucket/daily_distribution_data
aws s3 sync ../data/daily_moments_data s3://your-bucket/daily_moments_data

# Optional: update a "last updated" timestamp
echo $(date) > ../data/last_updated.txt
aws s3 cp ../data/last_updated.txt s3://kalshi-and-the-rise-of-macro-markets/
```

**For Daily Automation:**

1. **GitHub Actions** 
   - Add your Kalshi API credentials and cloud storage credentials as GitHub Secrets
   - Schedule via cron (e.g., daily at 7 AM EST)
