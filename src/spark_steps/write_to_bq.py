from pyspark.sql.dataframe import DataFrame


def write_to_bq(df: DataFrame,
                    table: str) -> int:
    """
    :param stocks_df: Dataframe
    :param table: table_name
    :return: Status
    """
    (df
     .write.format('bigquery')
     .mode("append")
     .option('table', table)
     .save()
     )

    return 0
