PROJECT_ID ?= <project_id>
REGION ?= <region>
CODE_BUCKET ?= <code_bucket>
TEMP_BUCKET ?= <temp_bucket>
DATA_BUCKET ?= <data_bucket>
DATA_SET_NAME ?= <data_set_name>
PROJECT_NUMBER ?= $$(gcloud projects list --filter=${PROJECT_ID} --format="value(PROJECT_NUMBER)")
APP_NAME ?= $$(cat pyproject.toml| grep name | cut -d" " -f3 | sed  's/"//g')
VERSION_NO ?= $$(poetry version --short)
SRC_WITH_DEPS ?= src_with_deps

.PHONY: $(shell sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' $(MAKEFILE_LIST))

.DEFAULT_GOAL := help

help: ## This is help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Setup Buckets and Dataset, run one time
	@echo "Project=${PROJECT_ID}--${PROJECT_NUMBER}--${CODE_BUCKET}--${TEMP_BUCKET}"
	@gsutil mb -c standard -l ${REGION} -p ${PROJECT_ID} gs://${CODE_BUCKET}
	@gsutil mb -c standard -l ${REGION} -p ${PROJECT_ID} gs://${TEMP_BUCKET}
	@gsutil mb -c standard -l ${REGION} -p ${PROJECT_ID} gs://${DATA_BUCKET}
	@gsutil cp ./data/10-sample-pulseperson-rows.csv gs://${DATA_BUCKET}
	@bq mk --location=${REGION} -d --project_id=${PROJECT_ID} --quiet ${DATA_SET_NAME}
	@echo "The Following Buckets created - ${CODE_BUCKET}, ${TEMP_BUCKET}, ${DATA_BUCKET} and 1 BQ Dataset ${DATA_SET_NAME} Created in GCP"

clean: ## CleanUp Prior to Build
	@rm -Rf ./dist
	@rm -Rf ./${SRC_WITH_DEPS}
	@rm -f requirements.txt

build: clean ## Build Python Package with Dependencies
	@echo "Packaging Code and Dependencies for ${APP_NAME}-${VERSION_NO}"
	@mkdir -p ./dist
	@poetry update
	@poetry export -f requirements.txt --without-hashes -o requirements.txt
	@poetry run pip install . -r requirements.txt -t ${SRC_WITH_DEPS}
	@cd ./${SRC_WITH_DEPS}
	@find . -name "*.pyc" -delete
	@cd ./${SRC_WITH_DEPS} && zip -x "*.git*" -x "*.DS_Store" -x "*.pyc" -x "*/*__pycache__*/" -x ".idea*" -r ../dist/${SRC_WITH_DEPS}.zip .
	@rm -Rf ./${SRC_WITH_DEPS}
	@rm -f requirements.txt
	@cp ./src/main.py ./dist
	@mv ./dist/${SRC_WITH_DEPS}.zip ./dist/${APP_NAME}_${VERSION_NO}.zip
	@gsutil cp -r ./dist gs://${CODE_BUCKET}


run: ## Run an example job as a dataproc serverless job
	gcloud dataproc batches submit --project ${PROJECT_ID} --region ${REGION} pyspark \
	gs://${CODE_BUCKET}/dist/main.py --py-files=gs://${CODE_BUCKET}/dist/${APP_NAME}_${VERSION_NO}.zip \
	--subnet default --version 2.1 --properties spark.executor.instances=2,spark.driver.cores=4,spark.executor.cores=4,spark.app.name=dataproc-pyspark-examples \
	--jars gs://spark-lib/bigquery/spark-bigquery-latest.jar \
	-- --project=${PROJECT_ID} --file-uri=gs://${DATA_BUCKET}/10-sample-pulseperson-rows.csv --temp-bq-bucket=${TEMP_BUCKET}