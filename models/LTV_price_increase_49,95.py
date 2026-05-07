##Packages
import arviz as az
import pandas as pd
import numpy as np
import pymc as pm
import pytensor.tensor as pt
import matplotlib.pyplot as plt
from sklearn.metrics import roc_auc_score
from scipy.special import expit
import seaborn as sns

#Import File
file_path = "/content/_SELECT_s_id_AS_subscription_id_SUM_CASE_WHEN_t_transaction_type_202605061303.csv"
df = pd.read_csv(file_path)

##Data preprocessing##
#No annual plan
#Churned normalized
#Tiers definition
#Country filter (more than 50 users)
obs_end = pd.to_datetime('2026-04-20')
df['initial_payment_date'] = pd.to_datetime(df['initial_payment_date'])
df = df[df['initial_payment_date'] <= obs_end].copy()
df = df[df['amount'] < 100].copy() # No anual plan
df['tenure'] = df['tenure'] - 1
df = df[df['tenure'] >= 0].copy()
df['churned'] = np.where(df['status'] == 'churned', 1, 0)
tier_map = {
    'US': 'T1_CORE_ENG', 'CA': 'T1_CORE_ENG', 'GB': 'T1_CORE_ENG', 'AU': 'T1_CORE_ENG', 'NZ': 'T1_CORE_ENG',
    'DE': 'T2_WEST_EU', 'FR': 'T2_WEST_EU', 'NL': 'T2_WEST_EU', 'BE': 'T2_WEST_EU', 'AT': 'T2_WEST_EU', 'CH': 'T2_WEST_EU', 'DK': 'T2_WEST_EU', 'SE': 'T2_WEST_EU', 'NO': 'T2_WEST_EU', 'PL': 'T2_WEST_EU',
    'ES': 'T3_MED_LATAM_PREM', 'IT': 'T3_MED_LATAM_PREM', 'MX': 'T3_MED_LATAM_PREM', 'CL': 'T3_MED_LATAM_PREM', 'BR': 'T3_MED_LATAM_PREM',
    'CO': 'T4_EMERGING', 'AR': 'T4_EMERGING', 'PE': 'T4_EMERGING', 'EC': 'T4_EMERGING', 'UY': 'T4_EMERGING', 'VE': 'T4_EMERGING', 'TR': 'T4_EMERGING', 'IN': 'T4_EMERGING', 'PH': 'T4_EMERGING',
    'JP': 'T5_SPECIAL', 'KR': 'T5_SPECIAL', 'SG': 'T5_SPECIAL', 'SA': 'T5_SPECIAL'
}
df['tier'] = df['ip_country'].map(tier_map)
country_counts = df['ip_country'].value_counts()
valid_countries = country_counts[country_counts >= 50].index.tolist()
df= df[
    (df['tier'].notna()) &              # Inside the tier
    (df['ip_country'].isin(valid_countries)) # Enought volume
].copy()

