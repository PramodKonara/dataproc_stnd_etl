from pyspark.sql.dataframe import DataFrame
from pyspark.sql.functions import date_format


def transform_person_df(df: DataFrame) -> DataFrame:
    transformed_df = df.withColumn('createdate', date_format('createdate',"yyyy-MM-dd"))
    return transformed_df
