
from typing import Optional
from codetiming import Timer

import argparse

from src.spark_steps.read_gsc_file import read_gsc_file
from src.spark_steps.transform_person_df import transform_person_df
from src.spark_steps.write_to_bq import write_to_bq
from src.utils.setup_spark import start_spark
from src.utils.timer_utils import timer_args


def run(app_name: Optional[str],
        bucket: str,
        file_uri: str) -> None:

    total_time = Timer(**timer_args("Total run time"))
    total_time.start()

    dataset_name = "dataproc_pulse_person"
    table_name = "person"

    with Timer(**timer_args('Spark Connection')):
        spark = start_spark(app_name=app_name,
                            bucket=bucket)

    with Timer(**timer_args('Read File From GCS')):
        person_df = read_gsc_file(spark=spark,
                              file_uri=file_uri)

    with Timer(**timer_args('Transform DF')):
        transformed_person_df = transform_person_df(df=person_df)

    with Timer(**timer_args('Write DF to Bigquery')):
        status = write_to_bq(df=transformed_person_df,
                                 table=f'{dataset_name}.{table_name}')

    total_time.stop()
    print(Timer.timers)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()

    parser.add_argument(
        '--file-uri',
        type=str,
        dest='file_uri',
        required=True,
        help='URI of the GCS bucket, for example, gs://bucket_name/file_name')

    parser.add_argument(
        '--project',
        type=str,
        dest='project_id',
        required=True,
        help='GCP Project ID')

    parser.add_argument(
        '--temp-bq-bucket',
        type=str,
        dest='temp_bq_bucket',
        required=True,
        help='Name of the Temp GCP Bucket -- just the bucket name itself, DO NOT add the gs:// Prefix')

    known_args, pipeline_args = parser.parse_known_args()

    run(app_name="dataproc-pyspark-example",
        bucket=known_args.temp_bq_bucket,
        file_uri=known_args.file_uri)
