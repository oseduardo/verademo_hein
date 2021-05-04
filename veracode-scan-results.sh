#/bin/bash

        #$1 VID
        #$2 VKEY
        #$3 BUILD_ID
        #$4 SANDBOX_NAME

        echo ""
        echo '====== DEBUG START ======'
        echo 'API-ID: ' $1
        echo 'API-Key: ' $2
        echo 'Buil_Id: ' $3
        echo 'Sandbox-Name: ' $4
        echo '====== DEBUG END ======'
        echo ""

        PRESCAN_SLEEP_TIME=60
        SCAN_SLEEP_TIME=120
        JAVA_WRAPPER_LOCATION="."
        OUTPUT_FILE_LOCATION="."
        OUTPUT_FILE_NAME='VeracodeDetailedReport-Build_ID'$3'.xml'
        OUTPUT_TEMP_FILE=$3'_tempfile.txt'
        echo '[INFO] ------------------------------------------------------------------------'
        echo '[INFO] DOWNLOADING VERACODE JAVA WRAPPER'
        if `wget https://repo1.maven.org/maven2/com/veracode/vosp/api/wrappers/vosp-api-wrappers-java/21.4.7.5/vosp-api-wrappers-java-21.4.7.5.jar -O VeracodeJavaAPI.jar`; then
                chmod 755 VeracodeJavaAPI.jar
                echo '[INFO] SUCCESSFULLY DOWNLOADED WRAPPER'
        else
                echo '[ERROR] DOWNLOAD FAILED'
                exit 1
        fi

        # Check if it's a Sandbox Scan
        if [[ "$4" != "" ]]; then
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

        #Check scan status
        echo ""
        echo "[INFO] checking scan status"

        while true;
        do

             if [ -z "$sandbox_ID" ];
             then
               #Check Policy Scan Status
               java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action getbuildinfo -appid $app_ID > $OUTPUT_TEMP_FILE 2>&1
             else
               #Check Sandbox Scan Status
               java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action getbuildinfo -appid $app_ID -sandboxid $sandbox_ID > $OUTPUT_TEMP_FILE 2>&1
             fi

             scan_status=$(cat $OUTPUT_TEMP_FILE)
             if [[ $scan_status = *"Scan In Process"* ]];
             then
                   echo ""
                   echo '[INFO] scan in process ...'
                   echo '[INFO] wait 2 more minutes ...'
                   sleep $SCAN_SLEEP_TIME
             elif [[ $scan_status = *"Submitted to Engine"* ]];
             then
                   echo ""
                   echo '[INFO] Application submitted to scan engine'
                   echo '[INFO] Scan will start momentarily'
                   echo '[INFO] wait 1 more mintue'
                   sleep $PRESCAN_SLEEP_TIME
             elif [[ $scan_status = *"Pre-Scan Submitted"* ]];
             then
                   echo ""
                   echo '[INFO] pre-scan still running ...'
                   echo '[INFO] wait 1 more minute ...'
                  sleep $PRESCAN_SLEEP_TIME
             elif [[ $scan_status = *"Pre-Scan Success"* ]];
             then
                   if [ -z "$sandbox_ID" ];
                   then
                        #Getting Policy Pre-Scan Status
                        java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetPreScanResults -appid $app_ID > $OUTPUT_TEMP_FILE 2>&1
                   else
                        #Getting Sandbox Pre-Scan Status
                        java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetPreScanResults -appid $app_ID -sandboxid $sandbox_ID > $OUTPUT_TEMP_FILE 2>&1
                   fi


                   echo ""
                   echo '[ ERROR ] Something went wrong with the prescan!'
                   cat $OUTPUT_TEMP_FILE
                   rm -rf $OUTPUT_TEMP_FILE
                   exit 1 && break
             else
                   scan_finished=$(cat $OUTPUT_TEMP_FILE)
                   if [[ $scan_finished = *"Results Ready"* ]];
                   then
                        echo ""
                        echo '[INFO] scan has finished'
                        rm -rf $OUTPUT_TEMP_FILE
                        sleep $SCAN_SLEEP_TIME
                        break;
                   fi
             fi
        done

        echo ""
        echo '[INFO] Scan results'

        if [ -z "$sandbox_ID" ];
             then
                  #Getting Policy Scan PassFail
                  java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action passfail -appname $3 > $OUTPUT_TEMP_FILE 2>&1
                  scan_result=$(cat $OUTPUT_TEMP_FILE)

                  if [[ $scan_result = *"Did Not Pass"* ]];
                  then
                       echo 'Application: ' $3 '(App-ID '$app_ID') - Scanname: ' $5 '(Build-ID '$build_id') - Did NOT Pass'
                       rm -rf $OUTPUT_TEMP_FILE

                       #Getting Summary Report
                       echo ""
                       java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action summaryreport -buildid $build_id -outputfilepath $OUTPUT_TEMP_FILE"_SummaryReport.xml"
                       echo "[INFO] See Summary Report in " $OUTPUT_TEMP_FILE"_SummaryReport.xml file. For detailed report, please go to Veracode platform or download Detailed Report by using APIs"
                       echo ""
                       exit 1
                  else
                       echo 'Application: ' $3 '(App-ID '$app_ID') - Scanname: ' $5 '(Build-ID '$build_id') - Did Pass'
                       rm -rf $OUTPUT_TEMP_FILE

                       #Getting Summary Report
                       echo ""
                       java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action summaryreport -buildid $build_id -outputfilepath $OUTPUT_TEMP_FILE"_SummaryReport.xml"
                       echo "[INFO] See Summary Report in " $OUTPUT_TEMP_FILE"_SummaryReport.xml file. For detailed report, please go to Veracode platform or download Detailed Report by using APIs"
                       echo ""
                       exit 0
                  fi
               else
                  #A sandbox scan is not considered an official scan, so PassFail it's only available for Policy Scan
                  #Getting Summary Report
                  java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action summaryreport -buildid $build_id -outputfilepath $OUTPUT_TEMP_FILE"_SummaryReport.xml"
                  echo "[INFO] See Summary Report in " $OUTPUT_TEMP_FILE"_SummaryReport.xml file. For detailed report, please go to Veracode platform or download Detailed Report by using APIs"
                  echo ""
                  exit 0
        fi

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


        

        
