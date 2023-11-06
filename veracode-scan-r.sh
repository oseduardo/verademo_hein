#/bin/bash

        #$1 API-ID
        #$2 API-Key
        #$3 AppName
        #$4 Build working directory
        #$5 Build version (Scan name)
        #$6 Sandbox Name

        PRESCAN_SLEEP_TIME=60
        SCAN_SLEEP_TIME=120
        JAVA_WRAPPER_LOCATION="."
        OUTPUT_FILE_LOCATION="."
        OUTPUT_FILE_NAME=$3'-'$5'.txt'
        echo '[INFO] ------------------------------------------------------------------------'
        echo '[INFO] DOWNLOADING VERACODE JAVA WRAPPER'
        if `wget --no-check-certificate https://repo1.maven.org/maven2/com/veracode/vosp/api/wrappers/vosp-api-wrappers-java/23.4.11.2/vosp-api-wrappers-java-23.4.11.2.jar -O VeracodeJavaAPI.jar`; then
                chmod 755 VeracodeJavaAPI.jar
                echo '[INFO] SUCCESSFULLY DOWNLOADED WRAPPER'
        else
                echo '[ERROR] DOWNLOAD FAILED'
                exit 1
        fi

        echo '[INFO] ------------------------------------------------------------------------'
        echo '[INFO] VERACODE UPLOAD AND SCAN'

        app_ID=$(java -verbose -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetAppList | grep -w \"$3\" | sed -n 's/.* app_id=\"\([0-9]*\)\" .*/\1/p')

        if [ -z "$app_ID" ];
        then
             echo '[INFO] App does not exist'
             echo '[INFO] create app: ' $3
             creat_addp=$(java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action createApp -appname "$3" -criticality high)
             echo '[INFO]app created'
             app_ID=$(java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetAppList | grep -w \"$3\" | sed -n 's/.* app_id=\"\([0-9]*\)\" .*/\1/p')
             echo '[INFO] new App-ID: ' $app_ID
             echo ""
        else
             echo '[INFO] App-IP: ' $app_ID
             echo ""
        fi

        # Check if it's a Sandbox Scan
        if [[ "$6" != "" ]]; then
          echo '[INFO] Validating Sandbox ID'
          sandbox_ID=$(java -verbose -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetSandboxList -appid $app_ID | grep -w "$6" | sed -n 's/.* sandbox_id=\"\([0-9]*\)\" .*/\1/p')
          
          if [ -z "$sandbox_ID" ];
          then
               echo '[INFO] Sandbox does not exist'
               echo '[INFO] Creating Sandbox: ' $6
               creat_sandbox=$(java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action createSandbox -appid $app_ID -sandboxname "$6")
               echo '[INFO] Sandbox created'
               sandbox_ID=$(java -verbose -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetSandboxList -appid $app_ID | grep -w "$6" | sed -n 's/.* sandbox_id=\"\([0-9]*\)\" .*/\1/p')
               echo '[INFO] New Sandbox ID: ' $sandbox_ID
          else
               echo 'Sandbox ID: ' $sandbox_ID
          fi
        else
          echo '[INFO] There is no a Sandbox specified. This is a Policy Scan'
        fi

        echo ""
        echo '====== DEBUG START ======'
        echo 'API-ID: ' $1
        echo 'API-Key: ' $2
        echo 'App-Name: ' $3
        echo 'Sandbox-Name: ' $6
        echo 'APP-ID: ' $app_ID
        echo 'File-Path: ' $4
        echo 'Scan-Name: ' $5
        echo '====== DEBUG END ======'
        echo ""


        echo '[INFO] VERACODE scan pre-checks'
        echo '[INFO] directory checks'
        # Directory argument
        if [[ "$4" != "" ]]; then
             UPLOAD_DIR="$4"
        else
             echo "[ERROR] Directory not specified."
             exit 1
        fi
     
        # Check if directory exists
        if ! [[ -f "$UPLOAD_DIR" ]];
        then
             echo "[ERROR] File does not exist"
             exit 1
        else
             echo '[INFO] File set to '$UPLOAD_DIR
        fi

        # Version argument
        if [[ "$5" != "" ]];
        then
             VERSION=$5
        else
             VERSION=`date "+%Y-%m-%d %T"`    # Use date as default
        fi
        echo '[INFO] Scan-Name set to '$VERSION
        echo ""

        OUTPUT_FILE_FULL_PATH=$OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME

        #Upload files, start prescan and scan
        echo '[INFO] upload and scan'
        if [ -z "$sandbox_ID" ];
        then
          echo '[INFO] Starting Policy Scan...'
          java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action uploadandscan -appname $3 -createprofile true -filepath $4 -version $VERSION > $OUTPUT_FILE_FULL_PATH 2>&1
          echo ""
        else
          echo '[INFO] Starting Sandbox Scan...'
          java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action uploadandscan -appname $3 -createprofile true -sandboxname $6 -createsandbox false -filepath $4 -version $VERSION > $OUTPUT_FILE_FULL_PATH 2>&1
          echo ""
        fi

        echo $upload_scan_results

        upload_scan_results=$(cat $OUTPUT_FILE_FULL_PATH)

        if [[ $upload_scan_results == *"already exists"* ]];
        then
             echo ""
             echo '[ERROR] This scan name already exists'
             exit 1
        elif [[ $upload_scan_results == *"in progress or has failed"* ]];
        then
             echo ""
             echo '[ ERROR ] Something went wrong! A previous scan is in progress or has failed to complete successfully'
                exit 1
        else
             echo ""
             echo '[INFO] File(s) uploaded and PreScan started'
        fi

        rm -rf $OUTPUT_FILE_FULL_PATH