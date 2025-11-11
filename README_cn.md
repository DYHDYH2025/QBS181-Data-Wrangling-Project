# QBS181 纽约市 Airbnb 数据整备项目

本仓库记录了 QBS181 Data Wrangling 项目中，对纽约市 Airbnb 开放数据进行清洗、空间整合、建模与可视化的完整流程。本文档的目标是帮助从未接触过该数据的读者，在本地环境中完全复现我们的数据处理与分析管线，直至产出建模数据、分析结果与可视化输出。

---

## 仓库结构总览

```text
QBS181-Data-Wrangling-Project-main/
├── Analysis.Rmd                     # 建模与诊断分析
├── Final Analysis Data.Rmd          # 空间连接与建模底表生成
├── NY-ACS.Rmd                       # ACS (美国社区调查) 数据抓取
├── vis_data.Rmd                     # 可视化与探索性分析
├── SQL_Commands.sql                 # MySQL 宽表构建与清洗脚本
├── dw_data_approval (3).pdf         # 数据使用审批文件
├── Data/                            # 数据成果与输入目录（详见“数据字典”）
├── Data Cleaning/                   # 数据清洗脚本与中间结果
│   ├── Data Cleaning.Rmd
│   ├── df_cleaned_second_geo.py
│   └── Data/
│       ├── Airbnb_Open_Data_cleaned_first.csv
│       ├── df_cleaned_second.csv
│       └── airbnb_nyc_final_clean.csv
└── README.md
```

---

## 一键复现流程速览

| 阶段 | 脚本 / 文件 | 主要产出 |
| ---- | ----------- | -------- |
| 0. 环境准备 | - | R、Python、MySQL 等依赖可用 |
| 1. Airbnb 原始数据处理 | `Data Cleaning/Data Cleaning.Rmd` | `Airbnb_Open_Data_cleaned_first.csv`、`df_cleaned_second.csv` |
| 2. 反向地理编码补全 | `Data Cleaning/df_cleaned_second_geo.py` | `airbnb_nyc_final_clean.csv` |
| 3. ACS 社会经济数据获取 | `NY-ACS.Rmd` | `Data/nyc_acs_data.csv` |
| 4. 空间连接与建模底表 | `Final Analysis Data.Rmd` + `SQL_Commands.sql` | `final_analytics_base_table.csv`、`final_data.csv` |
| 5. 建模分析 | `Analysis.Rmd` | 回归模型诊断、`model_data.csv` |
| 6. 可视化与探索 | `vis_data.Rmd` | HTML 图表、交互式地图 |

各阶段的详细操作请见下文。

---

## 环境与依赖准备

### 操作系统建议
- Windows 10/11（仓库路径示例基于 `D:\2025_Fall\datawrang\group\QBS181-Data-Wrangling-Project-main`）
- macOS 或 Linux 亦可，但需注意文件路径与包安装方式的差异。

### R 与 RStudio
- 推荐使用 R 4.3+ 与 RStudio（或 Positron、Quarto 等 IDE）。
- 需安装以下 R 包（首次运行各 Rmd 时会自动提示安装）：`tidyverse`, `janitor`, `skimr`, `lubridate`, `sf`, `tmap`, `plotly`, `knitr`, `car`, `DBI`, `RMySQL`, `tidycensus`, `tigris`, `maptiles`, `tidyterra`, `leaflet`, `gridExtra`, `forcats`, `viridis`, `hrbrthemes`。
- 如果处于学校或企业网络环境，建议预先配置 CRAN 镜像以避免安装超时。

### Python（用于地理编码）
- 安装 Python 3.9+。
- 推荐创建虚拟环境后安装依赖：
  ```bash
  pip install pandas geopy
  ```
- 反向地理编码使用 Nominatim API，须遵循其使用条款（低频请求、设置自定义 `user_agent`）。

### 数据库
- MySQL 8.0+ 或 MariaDB 10.5+。
- 需要具备 `LOAD DATA LOCAL INFILE` 与 `SELECT ... INTO OUTFILE` 权限。
- 在本机创建数据库 `qbs181`（名称可自定义，但对应脚本需同步修改）。
- 确认 MySQL 服务器允许本地文件导入导出（Windows 用户在 `my.ini` 中启用 `local_infile=1`）。

### 其他外部资源
- **Census API Key**：访问 https://api.census.gov/data/key_signup.html 申请（免费）。
- **地理边界文件**：部分可视化依赖 `neighbourhoods.geojson`（未收录于仓库，可从 NYC Open Data 或 Inside Airbnb 下载）。
- 若使用 RStudio Knit 功能导出 PDF/HTML，请预先安装 TinyTeX 或其它 LaTeX 发行版。

---

## 详细复现步骤

### 0. 准备工作目录
1. 克隆或下载仓库至本地。
2. 在 RStudio 中将工作目录设为仓库根目录：
   ```r
   setwd("D:/2025_Fall/datawrang/group/QBS181-Data-Wrangling-Project-main")
   ```
3. 确认 `Data/`、`Data Cleaning/Data/` 文件夹具备读写权限。

### 1. 清洗 Airbnb 原始数据

**文件**：`Data Cleaning/Data Cleaning.Rmd`  
**目标**：处理 `Airbnb_Open_Data.xlsx` / `Airbnb_Open_Data_cleaned_first.csv`，统一列名、修复类型、填补缺失值。

操作步骤：
1. 在 RStudio 打开 `Data Cleaning.Rmd`，按顺序运行所有代码块（或点击 `Run All`）。
2. 关键处理环节：
   - 使用 `janitor::clean_names()` 标准化列名。
   - 将 `price`、`service_fee` 等列转换为数值。
   - 以中位数填补 `reviews_per_month`、`availability_365` 缺失值。
   - 将 `last_review` 统一转换为日期，并将缺失或超出 2021-01-01 的值替换为有效中位数。
   - 限制 `minimum_nights` 取值在 1~365，以去除异常。
3. 脚本会在 `Data Cleaning/Data/` 目录输出两个中间文件：`Airbnb_Open_Data_cleaned_first.csv`、`df_cleaned_second.csv`。

如需使用不同年份或地区的数据，请替换源文件，并确保字段命名兼容。

### 2. 反向地理编码补全行政区信息

**脚本**：`Data Cleaning/df_cleaned_second_geo.py`  
**目标**：利用经纬度补全缺失的 `neighbourhood_group` 与 `neighbourhood`。

操作步骤：
1. 在命令行进入脚本所在目录：
   ```cmd
   cd /d D:\2025_Fall\datawrang\group\QBS181-Data-Wrangling-Project-main\Data Cleaning
   ```
2. 运行脚本：
   ```cmd
   python df_cleaned_second_geo.py
   ```
3. 脚本默认读取 `df_cleaned_second.csv`，将补全结果保存为 `airbnb_nyc_final_clean.csv`。
4. 如遇 API 超时或速率限制，脚本会自动重试；若依旧失败，可稍后重跑或手工补齐。

最终生成的 `airbnb_nyc_final_clean.csv` 将作为后续空间分析与建模的数据源。

### 3. 获取 ACS 社会经济数据

**文件**：`NY-ACS.Rmd`  
**目标**：从 ACS 获取纽约市五区邮编级经济指标。

操作步骤：
1. 将 Census API Key 写入 R 环境变量或直接在 Rmd 中调用：
   ```r
   tidycensus::census_api_key("YOUR_KEY_HERE", install = TRUE, overwrite = TRUE)
   ```
2. 运行 Rmd 内代码，执行：
   - `tidycensus::get_acs()` 下载全国 ZCTA 数据，包含 `median_income`、`population`、`median_rent`。
   - `tigris::counties()` 获取纽约市五个行政区边界。
   - `sf::st_join()` 将 ZCTA 数据裁剪至纽约市范围。
3. 建议将结果保存为 `Data/nyc_acs_data.csv` 以备后续使用。

### 4. 空间连接与建模底表构建

**文件**：`Final Analysis Data.Rmd`、`SQL_Commands.sql`  
**目标**：将 Airbnb 数据与 ACS 指标进行空间连接，并生成建模宽表。

步骤 A：R 中的空间连接与透视
1. 运行 `Final Analysis Data.Rmd`，确保加载 `airbnb_nyc_final_clean.csv` 和 `nyc_acs_data`。
2. 主要环节：
   - 使用 `sf::st_as_sf()` 将 Airbnb 数据转为点对象。
   - 将 ACS 数据转换至 WGS84 (`crs = 4326`)。
   - 通过 `st_join()` 将社会经济指标附加至房源。
   - 利用 `pivot_wider()` 将变量透视为宽表。
3. 导出 `data/final_analytics_base_table.csv`、`data/final_analytics_base_table_wide_clean.csv`、`data/final_data.csv`。

步骤 B：MySQL 中的数据清洗与宽表生成
1. 登录 MySQL 并使用数据库 `qbs181`：
   ```sql
   CREATE DATABASE IF NOT EXISTS qbs181;
   USE qbs181;
   ```
2. 执行 `SQL_Commands.sql`（示例命令）：
   ```bash
   mysql -u <username> -p --local-infile=1 qbs181 < SQL_Commands.sql
   ```
3. 脚本将：
   - 创建 `final_analytics_base_table` 并导入 CSV。
   - 聚合生成 `final_analytics_base_table_wide`。
   - 清洗文本字段并导出 `final_analytics_base_table_wide_clean.csv`。
4. 若因权限无法执行 `SELECT ... INTO OUTFILE`，可在 R 中使用 `dbGetQuery()` 与 `write_csv()` 导出。

### 5. 建模与诊断分析

**文件**：`Analysis.Rmd`  
**目标**：构建线性回归模型、输出诊断与地理可视化。

操作步骤：
1. 确保 MySQL 中存在 `final_data` 表（或通过 R 读取 `final_data.csv`）。
2. 修改 `dbConnect()` 参数以匹配本地数据库凭证。
3. 运行 Rmd：
   - 查询建模数据并保存为 `data/model_data.csv`。
   - 构建 `log(price)` 的多元线性回归模型。
   - 调用 `run_model_diagnostics()` 输出 VIF 与残差图。
   - 生成收入分布与房价散点地图。

### 6. 可视化与探索性分析

**文件**：`vis_data.Rmd`  
**目标**：输出静态与交互式图表。

操作步骤：
1. 确认 `airbnb_nyc_clean.csv` 已准备（可复制 `airbnb_nyc_final_clean.csv` 并重命名）。
2. 运行所有代码块生成：
   - 行政区房源数量、房型构成、热门社区柱状图。
   - 基于 MapTiles 的房价散点地图与 Leaflet 交互地图。
   - Plotly 房型地理散点图。
   - 最短入住夜数分布直方图。
3. 若需要分区统计图，请提供 `neighbourhoods.geojson` 并放置在仓库根目录。

### 7. 结果复核与归档

请确认以下关键成果文件存在：
- `Data/airbnb_nyc_final_clean.csv`
- `Data/final_data.csv`
- `Data/model_data.csv`
- Knit 输出的分析报告（PDF/HTML）

建议将上述文件及运行日志统一归档，便于团队复核与后续扩展。

---

## 数据字典与文件说明

| 文件路径 | 描述 | 生成方式 |
| -------- | ---- | -------- |
| `Data/Airbnb_Open_Data.xlsx` | 原始 Airbnb 纽约市数据（2019） | 外部数据源，需手动下载 |
| `Data Cleaning/Data/Airbnb_Open_Data_cleaned_first.csv` | 初步清洗（标准化列名、初步类型转换） | `Data Cleaning.Rmd` |
| `Data Cleaning/Data/df_cleaned_second.csv` | 二次清洗（缺失值填补、数值修正） | `Data Cleaning.Rmd` |
| `Data Cleaning/Data/airbnb_nyc_final_clean.csv` | 反向地理编码补全后的主数据 | `df_cleaned_second_geo.py` |
| `Data/nyc_acs_data.csv` | 纽约市 ZCTA 社会经济指标 | `NY-ACS.Rmd` |
| `Data/final_analytics_base_table.csv` | 空间连接后的长表 | `Final Analysis Data.Rmd` |
| `Data/final_analytics_base_table_wide.csv` | 初始宽表（含多变量列） | `Final Analysis Data.Rmd` |
| `Data/final_analytics_base_table_wide_clean.csv` | 去除换行符后的宽表 | `SQL_Commands.sql` |
| `Data/final_data.csv` | 建模基础数据 | `Final Analysis Data.Rmd` |
| `Data/model_data.csv` | 回归模型特征表 | `Analysis.Rmd` |

> 若需更改路径或文件名，请同步更新所有脚本中的读取与写入语句。

---

## 常见问题排错

- **R 包安装失败**：尝试切换 CRAN 镜像，或执行 `options(repos = "https://cloud.r-project.org")`。
- **sf/tigris 安装报错**：Windows 用户安装 Rtools；macOS 安装 Xcode Command Line Tools 并通过 Homebrew 安装 `gdal`/`geos`。
- **MySQL 导入/导出失败**：开启 `local_infile`，并确保目标目录具备写入权限。
- **Nominatim 调用超时**：脚本已内置重试机制，可改为分批运行或降低频率。
- **Census API 限流**：避免频繁重复请求，可缓存已下载的 `nyc_acs_data`。
- **路径包含空格或中文**：建议使用纯英文路径，或在 R 中调用 `normalizePath()`。

---

## 参考与致谢

- [Inside Airbnb](http://insideairbnb.com/get-the-data.html)：Airbnb 开放数据来源
- [US Census Bureau](https://www.census.gov/data/developers/data-sets/acs-5year.html)：ACS 五年期数据
- [Nominatim](https://nominatim.openstreetmap.org/)：反向地理编码服务
- R tidyverse、sf、leaflet 等开源社区

如在复现过程中遇到新的问题或发现可改进之处，欢迎提交 Issue 或 Pull Request，与团队共同完善本项目的可复现性。
