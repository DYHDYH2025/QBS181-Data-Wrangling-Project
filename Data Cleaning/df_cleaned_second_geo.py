import pandas as pd
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
import time

# --- 1. 设置路径和加载数据 ---

# 请确保路径与您在 R 中保存的路径一致！
INPUT_PATH = "df_cleaned_second.csv"
OUTPUT_PATH = "airbnb_nyc_final_clean.csv"

try:
    df = pd.read_csv(INPUT_PATH, encoding='latin-1')
except FileNotFoundError:
    print(f"错误：文件未找到，请检查路径是否正确: {INPUT_PATH}")
    # 您可能需要更改 INPUT_PATH
    exit()

print(f"成功加载数据，共 {len(df)} 行。")

# --- 2. 找出需要地理编码的行 ---

# 在 R 中，缺失值被填充为 'Unknown'。我们只对这些行进行 API 调用。
# 注意：neighbourhood_group 和 neighbourhood 是 R 中 janitor 规范化后的列名。
rows_to_geocode = df[
    (df['neighbourhood_group'] == 'Unknown') | 
    (df['neighbourhood'].isna())
].copy()

if rows_to_geocode.empty:
    print("没有缺失的地理信息需要通过 API 填充。跳过地理编码步骤。")
    df.to_csv(OUTPUT_PATH, index=False)
    exit()

print(f"发现 {len(rows_to_geocode)} 行需要进行反向地理编码...")

# --- 3. 配置地理编码器和速率限制 ---

# 关键修正：增加 timeout 参数到 10 秒
geolocator = Nominatim(user_agent="airbnb_nyc_analysis_script", timeout=10) 
# 速率限制：确保每秒不超过 1 次请求
geocode_limited = RateLimiter(geolocator.reverse, min_delay_seconds=1.0) 

# --- 4. 执行反向地理编码 ---

def get_location_info(row):
    """根据经纬度调用 API 获取地理信息，并处理超时"""
    # 增加重试机制
    MAX_RETRIES = 3
    for attempt in range(MAX_RETRIES):
        try:
            # 使用 RateLimiter 后的 geocode_limited 函数
            location = geocode_limited((row['lat'], row['long']))
            
            if location and location.raw and 'address' in location.raw:
                address = location.raw['address']
                
                # 提取行政区 (Nominatim 可能会返回 city/county/borough)
                group = address.get('borough') or address.get('county') or address.get('city')
                
                # 提取街区/路名
                hood = address.get('neighbourhood') or address.get('suburb')
                
                return pd.Series([group, hood])
            
        except GeocoderTimedOut:
            # 仅在超时时重试
            print(f"超时重试 ({attempt + 1}/{MAX_RETRIES})...")
            time.sleep(2 * (attempt + 1)) # 延长等待时间
            continue 
            
        except GeocoderServiceError as e:
            # 处理其他服务错误 (如速率限制被触发)
            print(f"服务错误: {e}. 等待 5 秒后重试...")
            time.sleep(5)
            continue
            
        except Exception as e:
            # 处理其他未知错误
            print(f"其他失败: {e}. 经纬度: ({row['lat']}, {row['long']})")
            break # 不重试，直接退出
            
    return pd.Series([None, None]) # 重试失败或出错则返回 None


# 对需要地理编码的行应用函数
print("开始地理编码。此过程可能需要较长时间...")
rows_to_geocode[['new_neighbourhood_group', 'new_neighbourhood']] = rows_to_geocode.apply(
    get_location_info, axis=1
)

print("地理编码完成。")

# --- 5. 更新主数据框并进行最后清理 ---

for index, row in rows_to_geocode.iterrows():
    if row['new_neighbourhood_group'] and row['neighbourhood_group'] == 'Unknown':
        df.loc[index, 'neighbourhood_group'] = row['new_neighbourhood_group']
        
    if row['new_neighbourhood'] and pd.isna(df.loc[index, 'neighbourhood']):
        df.loc[index, 'neighbourhood'] = row['new_neighbourhood']

df['neighbourhood_group'].fillna('Unresolved_API', inplace=True)
df['neighbourhood'].fillna('Unresolved_API', inplace=True)


# --- 6. 导出最终干净的数据集 ---

print(f"最终数据集已准备好，保存到 {OUTPUT_PATH}")
df.to_csv(OUTPUT_PATH, index=False, encoding='utf-8')
