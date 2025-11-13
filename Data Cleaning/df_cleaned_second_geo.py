import pandas as pd
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
import time

# --- 1. Set path and load data ---

# Make sure the path matches where you saved the file in R!
INPUT_PATH = "df_cleaned_second.csv"
OUTPUT_PATH = "airbnb_nyc_final_clean.csv"

try:
    df = pd.read_csv(INPUT_PATH, encoding='latin-1')
except FileNotFoundError:
    print(f"Error: File not found. Please check the path: {INPUT_PATH}")
    # You may need to update INPUT_PATH
    exit()

print(f"Data loaded successfully, total {len(df)} rows.")

# --- 2. Identify rows that need geocoding ---

# In R, missing values were filled as 'Unknown'. We only call the API for these rows.
# Note: neighbourhood_group and neighbourhood are standardized column names by janitor in R.
rows_to_geocode = df[
    (df['neighbourhood_group'] == 'Unknown') | 
    (df['neighbourhood'].isna())
].copy()

if rows_to_geocode.empty:
    print("No missing geographic values need to be filled via API. Skipping geocoding step.")
    df.to_csv(OUTPUT_PATH, index=False)
    exit()

print(f"Found {len(rows_to_geocode)} rows requiring reverse geocoding...")

# --- 3. Configure geocoder and rate limits ---

# Important fix: increase timeout to 10 seconds
geolocator = Nominatim(user_agent="airbnb_nyc_analysis_script", timeout=10)
# Rate limit: ensure no more than one request per second
geocode_limited = RateLimiter(geolocator.reverse, min_delay_seconds=1.0)

# --- 4. Perform reverse geocoding ---

def get_location_info(row):
    """Call API based on lat/long and return location info with retry handling"""
    MAX_RETRIES = 3
    for attempt in range(MAX_RETRIES):
        try:
            # Use the RateLimiter-wrapped function
            location = geocode_limited((row['lat'], row['long']))
            
            if location and location.raw and 'address' in location.raw:
                address = location.raw['address']
                
                # Extract borough/county/city
                group = address.get('borough') or address.get('county') or address.get('city')
                
                # Extract neighbourhood/suburb
                hood = address.get('neighbourhood') or address.get('suburb')
                
                return pd.Series([group, hood])
            
        except GeocoderTimedOut:
            # Retry only if timeout
            print(f"Timeout retry ({attempt + 1}/{MAX_RETRIES})...")
            time.sleep(2 * (attempt + 1))  # Increase wait time
            continue
            
        except GeocoderServiceError as e:
            # Handle API service errors (e.g., rate limit triggered)
            print(f"Service error: {e}. Waiting 5 seconds before retry...")
            time.sleep(5)
            continue
            
        except Exception as e:
            # Handle unexpected errors
            print(f"Unexpected failure: {e}. Coordinates: ({row['lat']}, {row['long']})")
            break  # Stop retrying
            
    return pd.Series([None, None])  # Return None if all retries fail


# Apply geocoding to required rows
print("Starting geocoding. This may take a while...")
rows_to_geocode[['new_neighbourhood_group', 'new_neighbourhood']] = rows_to_geocode.apply(
    get_location_info, axis=1
)

print("Geocoding completed.")

# --- 5. Update main dataframe and final cleanup ---

for index, row in rows_to_geocode.iterrows():
    if row['new_neighbourhood_group'] and row['neighbourhood_group'] == 'Unknown':
        df.loc[index, 'neighbourhood_group'] = row['new_neighbourhood_group']
        
    if row['new_neighbourhood'] and pd.isna(df.loc[index, 'neighbourhood']):
        df.loc[index, 'neighbourhood'] = row['new_neighbourhood']

df['neighbourhood_group'].fillna('Unresolved_API', inplace=True)
df['neighbourhood'].fillna('Unresolved_API', inplace=True)

# --- 6. Export final cleaned dataset ---

print(f"Final dataset ready, saving to {OUTPUT_PATH}")
df.to_csv(OUTPUT_PATH, index=False, encoding='utf-8')
