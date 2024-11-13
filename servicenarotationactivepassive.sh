#!/bin/bash

# Define the path to the users file and output directory
USERS_FILE="/home/mike/mike.txt"
OUTPUT_DIR="/home/mike/MikeNewkeys"
logfile="/home/mike/MikeNewkeys/rotation_keys.log"

# Initialize an array to store users with old keys
OLD_KEYS_USERS=()

# Get the current date for file naming
CURRENT_DATE=$(date +"%Y-%m-%d")

# Function to validate usernames
function is_valid_username() {
    local username="$1"
    [[ "$username" =~ ^[a-zA-Z0-9+=,.@_-]+$ ]]
}

# Check the creation time of the access keys
while IFS= read -r USER; do
    # Validate the username
    if ! is_valid_username "$USER"; then
        echo "Invalid username: $USER. Skipping..." >> $logfile
        continue
    fi

    # Notify which user is being processed
    echo "Checking access keys for user: $USER"  >> $logfile

    # Get the current access keys for the user
    ACCESS_KEYS=$(aws iam list-access-keys --user-name "$USER" --output json)

    # Check if the user has access keys
    if [[ $(echo "$ACCESS_KEYS" | jq '.AccessKeyMetadata | length') -gt 0 ]]; then
        ACTIVE_KEYS=()
        INACTIVE_KEY_ID=""

        # Loop through each access key for the user
        for KEY in $(echo "$ACCESS_KEYS" | jq -c '.AccessKeyMetadata[]'); do
            KEY_STATUS=$(echo "$KEY" | jq -r .Status)
            CREATION_DATE=$(echo "$KEY" | jq -r .CreateDate)
            ACCESS_KEY_ID=$(echo "$KEY" | jq -r .AccessKeyId)

            # Fetch the last used date using aws iam get-access-key-last-used
            ACCESS_KEY_LAST_USED=$(aws iam get-access-key-last-used --access-key-id "$ACCESS_KEY_ID")
            SERVICE_NAME=$(echo "$ACCESS_KEY_LAST_USED" | jq -r '.AccessKeyLastUsed.ServiceName')
            LAST_USED_DATE_RAW=$(echo "$ACCESS_KEY_LAST_USED" | jq -r '.AccessKeyLastUsed.LastUsedDate // "none"')

            # If the last used date is not "none", convert it to a comparable timestamp
            if [[ "$LAST_USED_DATE_RAW" != "none" ]]; then
                LAST_USED_DATE=$(date -d "$LAST_USED_DATE_RAW" +%s)  # Convert to Unix timestamp for comparison
            else
                LAST_USED_DATE="none"
            fi

            echo "--Initial creation date for $USER is $CREATION_DATE--" >> $logfile

            # Check if the key is active and store its details
            if [[ "$KEY_STATUS" == "Active" ]]; then
                ACTIVE_KEYS+=("$ACCESS_KEY_ID;$CREATION_DATE;$LAST_USED_DATE")
            else
                INACTIVE_KEY_ID="$ACCESS_KEY_ID"
            fi
        done

        # Determine the number of keys
        if [[ ${#ACTIVE_KEYS[@]} -eq 1 && -n "$INACTIVE_KEY_ID" ]]; then
            # User has one active key and one inactive key
            echo "User $USER has one active key and one inactive key. Checking conditions..."  >> $logfile

            # Extract details from the active key
            IFS=';' read -r ACTIVE_KEY_ID ACTIVE_CREATION_DATE ACTIVE_LAST_USED_DATE <<< "${ACTIVE_KEYS[0]}"
            ACTIVE_CREATION_EPOCH=$(date -d "${ACTIVE_CREATION_DATE//+00:00/UTC}" +%s)
            CURRENT_EPOCH=$(date +%s)
            echo " Activate key with keyid $ACTIVE_KEY_ID  Creation date for $USER is $ACTIVE_CREATION_DATE--" >> $logfile

            # Check if the active key is older than 30 days
            if [[ "$ACTIVE_LAST_USED_DATE" != "none" ]]; then
                if (( (CURRENT_EPOCH - ACTIVE_CREATION_EPOCH) > (30 * 24 * 3600) )); then
                    # Delete the inactive key
                    aws iam delete-access-key --user-name "$USER" --access-key-id "$INACTIVE_KEY_ID"
                    echo "Deleted inactive access key for user: $USER (Key ID: $INACTIVE_KEY_ID)"  >> $logfile

                    # Create a new access key for the user
                    ACCESS_KEY_INFO=$(aws iam create-access-key --user-name "$USER" --output json)
                    NEW_ACCESS_KEY_ID=$(echo "$ACCESS_KEY_INFO" | jq -r .AccessKey.AccessKeyId)
                    NEW_SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_INFO" | jq -r .AccessKey.SecretAccessKey)

                    # Write the new keys to the output file
                    OUTPUT_FILE="$OUTPUT_DIR/${USER}_access_keys.txt"
                    {
                        echo "User: $USER"
                        echo "Access Key ID: $NEW_ACCESS_KEY_ID created on ${CURRENT_DATE}"
                        echo "Secret Access Key: $NEW_SECRET_ACCESS_KEY created on ${CURRENT_DATE}"
                        echo "-----------------------------------"
                    } >> "$OUTPUT_FILE"

                    echo "Created new access keys for user: $USER and saved to $OUTPUT_FILE"  >> $logfile
                    OLD_KEYS_USERS+=("$USER")  # Add user to the old keys array for notification
                else
                    echo "The active key is not older than 30 days, no action taken."  >> $logfile
                fi
            else
                echo "Active key has never been used, skipping deletion of inactive key." >> $logfile
            fi
        elif [[ ${#ACTIVE_KEYS[@]} -eq 2 ]]; then
            # User has two active keys
            echo "User $USER has two active keys. Checking their last used dates..."  >> $logfile
            OLDEST_ACTIVE_KEY_ID=""
            OLDEST_LAST_USED_DATE_TS=""
	    OLDEST_LAST_USED_DATE_HUMAN=""
            KEY_WITH_NA=""

            for KEY_INFO in "${ACTIVE_KEYS[@]}"; do
                IFS=';' read -r KEY_ID KEY_CREATION_DATE KEY_LAST_USED_DATE <<< "$KEY_INFO"
                #echo "Checking KEY_ID: $KEY_ID, Last Used: $KEY_LAST_USED_DATE" >> $logfile

                # Get the actual last used date from AWS
                ACCESS_KEY_LAST_USED=$(aws iam get-access-key-last-used --access-key-id "$KEY_ID")
                SERVICE_NAME=$(echo "$ACCESS_KEY_LAST_USED" | jq -r '.AccessKeyLastUsed.ServiceName')
               # LAST_USED_DATE=$(echo "$ACCESS_KEY_LAST_USED" | jq -r '.AccessKeyLastUsed.LastUsedDate // "none"')

                # If the key was never used ("ServiceName": "N/A"), mark it for deletion
                if [[ "$SERVICE_NAME" == "N/A" ]]; then
                    KEY_WITH_NA="$KEY_ID"
                    echo "Key $KEY_ID has never been used (ServiceName: N/A), marking it for deletion." >> $logfile
                else
	            # Extract the LastUsedDate (it will be present if the key was used)		
                    LAST_USED_DATE=$(echo "$ACCESS_KEY_LAST_USED" | jq -r '.AccessKeyLastUsed.LastUsedDate')
		    # Convert LAST_USED_DATE to a Unix timestamp if it's not "none"
		    LAST_USED_DATE_TS=$(date -d "$LAST_USED_DATE" +%s 2>/dev/null) || LAST_USED_DATE_TS="invalid"
		    if [[ "$LAST_USED_DATE_TS" == "invalid" ]]; then
			echo "ERROR: Invalid last used date format for key $KEY_ID" >> $logfile
			continue
		    fi

		    # Log in human-readable format
		    LAST_USED_DATE_HUMAN=$(date -d "@$LAST_USED_DATE_TS" '+%Y-%m-%d %H:%M:%S %Z')
		    echo "Checking KEY_ID: $KEY_ID, Last Used: $LAST_USED_DATE_HUMAN" >> $logfile

		    # Compare keys based on the last used date
                    if [[ "$OLDEST_LAST_USED_DATE_TS" == "" || "$LAST_USED_DATE_TS" -lt "$OLDEST_LAST_USED_DATE_TS" ]]; then
                        OLDEST_LAST_USED_DATE_TS="$LAST_USED_DATE_TS"
                        OLDEST_ACTIVE_KEY_ID="$KEY_ID"
			OLDEST_LAST_USED_DATE_HUMAN="$LAST_USED_DATE_HUMAN"  # Store the human-readable date for the oldest key
                        echo "The oldest key is $OLDEST_ACTIVE_KEY_ID and was last used on $LAST_USED_DATE_HUMAN" >> $logfile
			OLDEST_KEY_CREATON_DATE="$KEY_CREATION_DATE"
			echo "the oldest key was created on $OLDEST_KEY_CREATON_DATE" >> $logfile
                    fi
                fi
            done

            # If one of the keys was never used, delete that key
            if [[ -n "$KEY_WITH_NA" ]]; then
                aws iam delete-access-key --user-name "$USER" --access-key-id "$KEY_WITH_NA"
                echo "Deleted access key that was never used for user: $USER (Key ID: $KEY_WITH_NA)"  >> $logfile
            else
		# Extract details from the oldest key
		#IFS=';' read -r ACTIVE_KEY_ID ACTIVE_CREATION_DATE ACTIVE_LAST_USED_DATE <<< "$OLDEST_ACTIVE_KEY_ID"
		ACTIVE_CREATION_EPOCH=$(date -d "${OLDEST_KEY_CREATON_DATE//+00:00/UTC}" +%s)
		CURRENT_EPOCH=$(date +%s)
		if (( (CURRENT_EPOCH - ACTIVE_CREATION_EPOCH) > (30 * 24 * 3600) )); then
		#use keinfo to get the accesskey info "wq!
		#echo " Oldestkey  key with keyid $ACTIVE_KEY_ID  Creation date for $USER is $ACTIVE_CREATION_DATE--" >> $logfile
                # If both keys were used, delete the oldest active key
                      aws iam delete-access-key --user-name "$USER" --access-key-id "$OLDEST_ACTIVE_KEY_ID"
                      echo "Deleted oldest active access key for user: $USER (Key ID: $OLDEST_ACTIVE_KEY_ID), Last Used: $OLDEST_LAST_USED_DATE"  >> $logfile
		      # Create a new access key for the user
		      ACCESS_KEY_INFO=$(aws iam create-access-key --user-name "$USER" --output json)
		      NEW_ACCESS_KEY_ID=$(echo "$ACCESS_KEY_INFO" | jq -r .AccessKey.AccessKeyId)
		      NEW_SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_INFO" | jq -r .AccessKey.SecretAccessKey)
		      # Write the new keys to the output file
		      OUTPUT_FILE="$OUTPUT_DIR/${USER}_access_keys.txt"
		      {
			  echo "User: $USER"
			  echo "Access Key ID: $NEW_ACCESS_KEY_ID created on ${CURRENT_DATE}"
			  echo "Secret Access Key: $NEW_SECRET_ACCESS_KEY created on ${CURRENT_DATE}"
			  echo "-----------------------------------"
		      }  >> "$OUTPUT_FILE"
		      echo "Created new access keys for user: $USER and saved to $OUTPUT_FILE"  >> $logfile
		else
		      echo "The oldest active  key for "$USER" is not older than 30 days; Deactivating it."  >> $logfile
		      aws iam update-access-key --access-key-id "$OLDEST_ACTIVE_KEY_ID" --status Inactive --user-name "$USER"
	        fi
            fi

            # Create a new access key for the user
            #ACCESS_KEY_INFO=$(aws iam create-access-key --user-name "$USER" --output json)
            #NEW_ACCESS_KEY_ID=$(echo "$ACCESS_KEY_INFO" | jq -r .AccessKey.AccessKeyId)
            #NEW_SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_INFO" | jq -r .AccessKey.SecretAccessKey)

            # Write the new keys to the output file
            #OUTPUT_FILE="$OUTPUT_DIR/${USER}_access_keys.txt"
           # {
                #echo "User: $USER"
                #echo "Access Key ID: $NEW_ACCESS_KEY_ID created on ${CURRENT_DATE}"
                #echo "Secret Access Key: $NEW_SECRET_ACCESS_KEY created on ${CURRENT_DATE}"
                #echo "-----------------------------------"
           # } >> "$OUTPUT_FILE"

            #echo "Created new access keys for user: $USER and saved to $OUTPUT_FILE"  >> $logfile
            OLD_KEYS_USERS+=("$USER")  # Add user to the old keys array for notification

        else
            echo "No valid conditions met for user: $USER."  >> $logfile
        fi
    else  
        echo "No access keys found for user: $USER"  >> $logfile
    fi
done < "$USERS_FILE"
:
