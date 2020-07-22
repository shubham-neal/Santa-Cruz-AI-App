#!/usr/bin/env bash

# Stop execution on any error from azure cli
set -e

# Define helper function for logging
info() {
    echo "$(date +"%Y-%m-%d %T") [INFO]"
}

# Define helper function for logging. This will change the Error text color to red
error() {
    echo "$(tput setaf 1)$(date +"%Y-%m-%d %T") [ERROR]"
}

# Generating a random number. This will be used in case a user provided name is not unique.
RANDOM_SUFFIX="${RANDOM:0:3}"

##############################################################################
# Check existence and value of a variable
# The function checks if the provided variable exists and it is a non-empty value.
# If it doesn't exists it adds the variable name to ARRAY_NOT_DEFINED_VARIABLES array and if it exists but doesn't have value, variable name is added ARRAY_VARIABLES_WITHOUT_VALUES array.
# In case a 3rd positional argument is provided, the function will output 1 if given variable exists and has a non-empty value, else it will output 0.
# Globals:
#	ARRAY_VARIABLES_WITHOUT_VALUES
#	ARRAY_NOT_DEFINED_VARIABLES
#	ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY
# Arguments:
#	Name of the variable
#	Value of the variable
#	Whether to print the result (Optional)
# Outputs:
#	The function writes the results if a 3rd positional parameter is passed in arguments
##############################################################################
checkValue() {
    # The first value passed to the function is the name of the variable
    # Check it's existence in file using -v
    if [ -v "$1" ]; then
        # The second value passed to the function is the actual value of the variable
        # Check if it is empty using -z
        if [ -z "$2" ]; then
            # If the value is empty, add the variable name ($1) to ARRAY_VARIABLES_WITHOUT_VALUES array and set ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY to false
            ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="false"
            ARRAY_VARIABLES_WITHOUT_VALUES+=("$1")
            # The third value is passed to the function when the caller expects the result
            # The function returns 0 as the value of the variable is empty
            if [ ! -z "$3" ]; then
                echo 0
            fi
        else
            # The third value is passed to the function when the caller expects the result
            # When the variable exists and it's value is not empty, function returns 1
            if [ ! -z "$3" ]; then
                echo 1
            fi
        fi
    else
        # If the variable is not defined, add the variable name to ARRAY_NOT_DEFINED_VARIABLES array and set ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY to false
        ARRAY_NOT_DEFINED_VARIABLES+=("$1")
        ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="false"
        # The third value is passed to the function when the caller expects the result
        # The function returns 0 as the variable is not defined
        if [ ! -z "$3" ]; then
            echo 0
        fi
    fi
}

printf "\n%60s\n" " " | tr ' ' '-'
echo "Checking if the required variables are configured"
printf "%60s\n" " " | tr ' ' '-'

VARIABLE_TEMPLATE_FILENAME="frontend-variables.template"

if [ ! -f "$VARIABLE_TEMPLATE_FILENAME" ]; then
    echo "$(error) \"$VARIABLE_TEMPLATE_FILENAME\" file is not present in current directory: \"$PWD\""
    exit 1
fi

# The following comment is for ignoring the source file check for shellcheck, as it does not support variable source file names currently
# shellcheck source=/dev/null
# Read variable values from VARIABLE_TEMPLATE_FILENAME file in current directory
source "$VARIABLE_TEMPLATE_FILENAME"

# Checking the existence and values of mandatory variables

# Setting default values for variable check stage
ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY="true"
ARRAY_VARIABLES_WITHOUT_VALUES=()
ARRAY_NOT_DEFINED_VARIABLES=()

# Pass the name of the variable and it's value to the checkValue function
checkValue "TENANT_ID" "$TENANT_ID"
checkValue "SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
checkValue "RESOURCE_GROUP" "$RESOURCE_GROUP"
checkValue "LOCATION" "$LOCATION"
checkValue "USE_EXISTING_RESOURCES" "$USE_EXISTING_RESOURCES"

checkValue "IOTHUB_NAME" "$IOTHUB_NAME"
checkValue "STORAGE_ACCOUNT_NAME" "$STORAGE_ACCOUNT_NAME"

checkValue "APP_SERVICE_PLAN_NAME" "$APP_SERVICE_PLAN_NAME"
checkValue "APP_SERVICE_PLAN_SKU" "$APP_SERVICE_PLAN_SKU"
checkValue "WEBAPP_NAME" "$WEBAPP_NAME"
checkValue "PASSWORD_FOR_WEBSITE_LOGIN" "$PASSWORD_FOR_WEBSITE_LOGIN"

IS_NOT_EMPTY=$(checkValue "USE_INTERACTIVE_LOGIN_FOR_AZURE" "$USE_INTERACTIVE_LOGIN_FOR_AZURE" "RETURN_VARIABLE_STATUS")
if [ "$IS_NOT_EMPTY" == "1" ] && [ "$USE_INTERACTIVE_LOGIN_FOR_AZURE" == "true" ]; then
    checkValue "SP_APP_ID" "$SP_APP_ID"
    checkValue "SP_APP_PWD" "$SP_APP_PWD"
fi

# Check if all the variables are set up correctly
if [ "$ARE_ALL_VARIABLES_CONFIGURED_CORRECTLY" == "false" ]; then
    # Check if there are any required variables which are not defined
    if [ "${#ARRAY_NOT_DEFINED_VARIABLES[@]}" -gt 0 ]; then
        echo "$(error) The following variables must be defined in the variables file"
        printf '%s\n' "${ARRAY_NOT_DEFINED_VARIABLES[@]}"
    fi
    # Check if there are any required variables which are empty
    if [ "${#ARRAY_VARIABLES_WITHOUT_VALUES[@]}" -gt 0 ]; then
        echo "$(error) The following variables must have a value in the variables file"
        printf '%s\n' "${ARRAY_VARIABLES_WITHOUT_VALUES[@]}"
    fi
    exit 1
fi

echo "$(info) The required variables are defined and have a non-empty value"

# Log into Azure
printf "\n%60s\n" " " | tr ' ' '-'
echo "Logging into Azure Subscription"
printf "%60s\n" " " | tr ' ' '-'

# This step checks the value for USE_INTERACTIVE_LOGIN_FOR_AZURE.
# If the value is true, the script will allow
if [ "$USE_INTERACTIVE_LOGIN_FOR_AZURE" == "true" ]; then
    echo "$(info) Attempting login"
    az login --tenant "$TENANT_ID" --output "none"
    echo "$(info) Login successful"
else
    echo "$(info) Attempting login with Service Principal account"
    # Using service principal as it will not require user interaction
    az login --service-principal --username "$SP_APP_ID" --password "$SP_APP_PWD" --tenant "$TENANT_ID" --output "none"
    echo "$(info) Login successful"
fi

# Set Azure Subscription
printf "\n%60s\n" " " | tr ' ' '-'
echo "Connecting to Azure Subscription"
printf "%60s\n" " " | tr ' ' '-'

echo "$(info) Setting current subscription to \"$SUBSCRIPTION_ID\""
az account set --subscription "$SUBSCRIPTION_ID"
echo "$(info) Successfully set subscription to \"$SUBSCRIPTION_ID\""

printf "\n%60s\n" " " | tr ' ' '-'
echo Configuring Front End Web App
printf "%60s\n" " " | tr ' ' '-'

SOLUTION_DIR="$PWD"

if [ -d ""$SOLUTION_DIR"/../ues-app" ] && [ -d ""$SOLUTION_DIR"/../ues-messages-app" ]; then

    NODE_VERSION=$(node -v)
    NPM_VERSION=$(npm -v)

    if [ -z "$NODE_VERSION" ] || [ -z "$NPM_VERSION" ]; then
        echo "$(error) This solution requires a recent version of npm and nodejs to be installed."
        echo "$(error) You do not currently have these packages, you must install them using the below commands."
        echo "$(error) curl -sL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
        echo "$(error) sudo apt-get install -y nodejs"
        exit 1
    fi

    echo "$(info) Building app"
    cd $SOLUTION_DIR/../ues-app/app
    npm install
    npm run build --prod --nomaps

    echo "$(info) Copying contents to front-end app"
    if [ -d ""$SOLUTION_DIR"/../ues-app/api/public" ]; then
        rm -r $SOLUTION_DIR/../ues-app/api/public
    fi
    cp -r build/ $SOLUTION_DIR/../ues-app/api/public

    cd $SOLUTION_DIR/../ues-app/api
    npm install

    echo "$(info) Zipping up solution for deployment"
    zip -r -q people-detection-app.zip .

    WEBAPP_DEPLOYMENT_ZIP=""$PWD"/people-detection-app.zip"

    cd "$SOLUTION_DIR"
else
    echo "$(error) use-app and use-messages-app repos must be present in the parent directory of setup.sh file"
    exit 1
fi

WEBAPP_RUNTIME="node|10.15"

# Retrieve IoT Hub Connection String
IOTHUB_CONNECTION_STRING="$(az iot hub show-connection-string --name "$IOTHUB_NAME" --query "connectionString" --output tsv)"

# Retrieve connection string for storage account
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g "$RESOURCE_GROUP" -n "$STORAGE_ACCOUNT_NAME" --query connectionString -o tsv)

# Set expiry date of token as current + 1 year
SAS_EXPIRY_DATE=$(date -u -d "1 year" '+%Y-%m-%dT%H:%MZ')
STORAGE_BLOB_SHARED_ACCESS_SIGNATURE=$(az storage account generate-sas --account-name "$STORAGE_ACCOUNT_NAME" --expiry "$SAS_EXPIRY_DATE" --permissions "lr" --resource-types "sco" --services "b" --connection-string "$STORAGE_CONNECTION_STRING" --output tsv)
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string --name "$STORAGE_ACCOUNT_NAME" --query "connectionString" --output tsv)

# Create CORS policy for frontend app
az storage cors add --account-name "$STORAGE_ACCOUNT_NAME" --connection-string $STORAGE_CONNECTION_STRING --services b --origins "*" --methods GET --allowed-headers "*" --exposed-headers "*" --max-age 1000

EXISTING_APP_SERVICE_PLAN=$(az appservice plan list --resource-group "$RESOURCE_GROUP" --query "[?name=='$APP_SERVICE_PLAN_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_APP_SERVICE_PLAN" ]; then
    echo "$(info) Creating App Service Plan \"$APP_SERVICE_PLAN_NAME\""
    az appservice plan create --name "$APP_SERVICE_PLAN_NAME" --sku "$APP_SERVICE_PLAN_SKU" --location "$LOCATION" --resource-group "$RESOURCE_GROUP" --output "none"
    echo "$(info) Created App Service Plan \"$APP_SERVICE_PLAN_NAME\""
else
    if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
        echo "$(info) Using existing App Service Plan \"$APP_SERVICE_PLAN_NAME\""
    else
        echo "$(info) App Service Plan \"$APP_SERVICE_PLAN_NAME\" already exists"
        echo "$(info) Appending a random number \"$RANDOM_SUFFIX\" to App Service Plan name \"$APP_SERVICE_PLAN_NAME\""
        APP_SERVICE_PLAN_NAME=${APP_SERVICE_PLAN_NAME}${RANDOM_SUFFIX}
        # Writing the updated value back to variables file
        sed -i 's#^\(APP_SERVICE_PLAN_NAME[ ]*=\).*#\1\"'"$APP_SERVICE_PLAN_NAME"'\"#g' "$VARIABLE_TEMPLATE_FILENAME"
        echo "$(info) Creating App Service Plan \"$APP_SERVICE_PLAN_NAME\""
        az appservice plan create --name "$APP_SERVICE_PLAN_NAME" --sku "$APP_SERVICE_PLAN_SKU" --location "$LOCATION" --resource-group "$RESOURCE_GROUP" --output "none"
        echo "$(info) Created App Service Plan \"$APP_SERVICE_PLAN_NAME\""
    fi
fi

EXISTING_WEB_APP=$(az webapp list --resource-group "$RESOURCE_GROUP" --query "[?name=='$WEBAPP_NAME'].{Name:name}" --output tsv)
if [ -z "$EXISTING_WEB_APP" ]; then
    echo "$(info) Creating Web App \"$WEBAPP_NAME\" in app service plan \"$APP_SERVICE_PLAN_NAME\""
    az webapp create --name "$WEBAPP_NAME" --plan "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP" --output "none"
    echo "$(info) Created webapp \"$WEBAPP_NAME\""
else
    if [ "$USE_EXISTING_RESOURCES" == "true" ]; then
        echo "$(info) Using existing Web App Plan \"$WEBAPP_NAME\""
    else
        echo "$(info) Web App \"$WEBAPP_NAME\" already exists"
        echo "$(info) Appending a random number \"$RANDOM_SUFFIX\" to Web App \"$WEBAPP_NAME\""
        WEBAPP_NAME=${WEBAPP_NAME}${RANDOM_SUFFIX}
        # Writing the updated value back to variables file
        sed -i 's#^\(WEBAPP_NAME[ ]*=\).*#\1\"'"$WEBAPP_NAME"'\"#g' "$VARIABLE_TEMPLATE_FILENAME"
        echo "$(info) Creating Web App \"$WEBAPP_NAME\""
        az webapp create --name "$WEBAPP_NAME" --plan "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP" --output "none"
        echo "$(info) Created Web app \"$WEBAPP_NAME\""
    fi
fi

echo "$(info) Updating config to add app settings, connection string and enable web sockets on webapp \"$WEBAPP_NAME\""

# Update appsettings on WebApp
# TBA: Check if this needs to be hard-coded
STORAGE_BLOB_PATH="Office/cam001"
WEBSITE_HTTPLOGGING_RETENTION_DAYS="7"
WEBSITE_NODE_DEFAULT_VERSION="10.15.2"
IMAGES_CONTAINER_NAME="still-images"

az webapp config appsettings set --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --settings "PASSWORD=$PASSWORD_FOR_WEBSITE_LOGIN" --output "none"
az webapp config appsettings set --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --settings "STORAGE_BLOB_ACCOUNT=$STORAGE_ACCOUNT_NAME" --output "none"
az webapp config appsettings set --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --settings "STORAGE_BLOB_CONTAINER_NAME=$IMAGES_CONTAINER_NAME" --output "none"
az webapp config appsettings set --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --settings "STORAGE_BLOB_PATH=$STORAGE_BLOB_PATH" --output "none"
az webapp config appsettings set --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --settings "STORAGE_BLOB_SHARED_ACCESS_SIGNATURE=$STORAGE_BLOB_SHARED_ACCESS_SIGNATURE" --output "none"
az webapp config appsettings set --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --settings "WEBSITE_HTTPLOGGING_RETENTION_DAYS=$WEBSITE_HTTPLOGGING_RETENTION_DAYS" --output "none"
az webapp config appsettings set --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --settings "WEBSITE_NODE_DEFAULT_VERSION=$WEBSITE_NODE_DEFAULT_VERSION" --output "none"

# Update connection string on WebApp
az webapp config connection-string set --connection-string-type Custom --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --settings "EventHub=$IOTHUB_CONNECTION_STRING" --output "none"

# Turn on web sockets
az webapp config set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --web-sockets-enabled true --output "none"

echo "$(info) Web App settings have been configured"

echo "$(info) Deploying Web App using \"$WEBAPP_DEPLOYMENT_ZIP\" zip file"
# Step to deploy the app to azure
az webapp deployment source config-zip --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --src "$WEBAPP_DEPLOYMENT_ZIP" --output "none"
echo "$(info) Deployment is complete"
