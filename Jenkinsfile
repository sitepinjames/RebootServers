pipeline {
    agent any
    
    parameters {
        choice(name: 'Platform', choices: ['Linux', 'Windows', 'All'], description: 'Select instance type to manage')
        
    }

    stages {
        stage('Setup AWS CLI') {
            steps {
                script {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: '4911f03a-73f3-4055-9fff-e4fe316422f6']]) {
                        sh 'aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID'
                        sh 'aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY'
                        sh 'aws configure set region us-east-1'
                    }
                }
            }
        }
        stage('Next Stop Linux Instances') {
            when {
                expression { params.Platform == 'Linux' || params.Platform == 'All' }
            }
            steps {
                script {
                    echo ' here Stopping The Following Linux Instances...'
                    // Add logic for stopping Linux instances
                    def linuxInstances = readFile('LinuxInstances.txt').split('\n').collect { it.trim() } 
                    sh "aws ec2 describe-instances --instance-ids i-078874a30cf0f048e --query 'Reservations[].Instances[].State.Name' --output text"
                    sh "aws ec2 describe-instances --instance-ids i-0f4871c3881d29215 --query 'Reservations[].Instances[].State.Name' --output text"
                    // Are instances running"?
                    def areInstancesRunning = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        echo " The Raw output from describe-instances: ${state}"
                        return state.split('\n').every { it == 'running' }
                    }
                    // Function to check if instances are stopped
                    def areInstancesStopped = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim().split()
                        return state.split('\n').every { it == 'stopped' }
                    }

                    def listAlreadyStopped(instanceIds) {
                        def stopped = []
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${instanceIds.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        def states = state.split('\n')
                        states.eachWithIndex { state, index ->
                            if (state == 'stopped') {
                            stopped << instanceIds[index]
                         }

                        }
                        echo "Stopped instances: ${stopped}"
                        return stopped
                    }
                    // Function to wait until all specified instances are stopped
                    def waitForInstancesToStop = { ids, maxWaitTime = 600, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                            def states = state.split("\\s+")
                            echo "Instance states: ${states}"
                            // Check each state individually and log
                            def allStopped = true
                            states.each { instanceState ->
                                echo "Instance state: ${instanceState}"
                                if (instanceState != 'stopped') {
                                    allStopped = false
                                }
                            }
                            if (allStopped) {
                                echo "All instances are now stopped."
                                return true
                            } else {
                                echo "Not all instances are stopped yet."
                            }
                            sleep(checkInterval) // Wait before checking again
                            waited += checkInterval
                        }
                        error "Timeout: Not all instances are stopped after ${maxWaitTime} seconds."
                    }       
                    // Define Linux instance IDs
                    //def stoppedLinuxInstances = areInstancesStopped(linuxInstances)
                    def stoppedLinuxInstances = listAlreadyStopped(linuxInstances)
                    def runningLinuxInstances = linuxInstances - stoppedLinuxInstances
                    echo "Stopped Linux Instances: ${stoppedLinuxInstances}"
                    echo "Running Linux Instances: ${runningLinuxInstances}"
                    if (runningLinuxInstances) {
                        sh "aws ec2 stop-instances --instance-ids ${runningLinuxInstances.join(' ')}"
                        waitForInstancesToStop(runningLinuxInstances,600,15)
                    }

                    if (stoppedLinuxInstances) {
                        echo "The following Linux instances were already stopped: ${stoppedLinuxInstances.join(', ')}"
                    }
                }
            }
        }
        stage('Stop Pega Admin Servers') {
            when {
                expression { params.Platform == 'Linux' || params.Platform == 'All' }
            }
            steps {
                script {
                    echo 'Stopping Pega Admin Servers...'
                    def pegaSercoServers = readFile('PagaAdminSerco.txt').split('\n').collect { it.trim() }// Pega Admin Serco for Low Env instances-dev-pro-imp    
                    def pegaAdmin2Servers = readFile('PagaAdmin2.txt').split('\n').collect { it.trim() }// Pega Admin2 for Low Env instances
                    def pegaAdmin3Servers = readFile('PagaAdmin3.txt').split('\n').collect { it.trim() }// Pega Admin3 for Low Env instances
                    /////////////////////////////////////////////////////////////////////////////////////////////////////////
                     // Function to check if instances are running
                    def areInstancesRunning = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        return state.split('\n').every { it == 'running' }
                    }
                    // Function to check if instances are stopped
                    def areInstancesStopped = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        return state.split('\n').every { it == 'stopped' }
                    }
                    // Function to list already stopped instances
                    def listAlreadyStopped = { ids ->
                        def states = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State[].Name' --output text", returnStdout: true).trim().split()
                        return ids.findAll { id ->
                            def index = ids.indexOf(id)
                            return states[index] == 'stopped'
                            }
                    }
                    def waitForInstancesToStop = { ids, maxWaitTime = 600, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                            def states = state.split("\\s+")
                            echo "Instance states: ${states}"
                            // Check each state individually and log
                            def allStopped = true
                            states.each { instanceState ->
                                echo "Instance state: ${instanceState}"
                                if (instanceState != 'stopped') {
                                    allStopped = false
                                }
                            }
                            if (allStopped) {
                                echo "All instances are now stopped."
                                return true
                            } else {
                                echo "Not all instances are stopped yet."
                            }
                            sleep(checkInterval) // Wait before checking again
                            waited += checkInterval
                        }
                        error "Timeout: Not all instances are stopped after ${maxWaitTime} seconds."
                    }       
                    // Stop the first instances of each environment simultaneously
                    //def stoppedpegaSercoServers = areInstancesStopped(pegaSercoServers)
                    def stoppedpegaSercoServers = listAlreadyStopped(pegaSercoServers)
                    def runninpegaSercoServers = pegaSercoServers - stoppedpegaSercoServers  

                    if (runninpegaSercoServers) {
                        echo "Stopping the following Pega Admin instances: ${runninpegaSercoServers.join(', ')}"
                        sh "aws ec2 stop-instances --instance-ids ${runninpegaSercoServers.join(' ')}"
                
                        // Wait for all first instances to stop
                        waitForInstancesToStop(runninpegaSercoServers,600,10)
                    }
                    // Report which first instances were already stopped
                    if (stoppedpegaSercoServers) {
                        echo "The following first Pega Admin instances were already stopped: ${stoppedpegaSercoServers.join(', ')}"
                    } 
                    sleep(5)// Stop the first instances of each environment simultaneously
                    def stoppedpegaAdmin2Servers = listAlreadyStopped(pegaAdmin2Servers)
                    //def stoppedpegaAdmin2Servers = areInstancesStopped(pegaAdmin2Servers)
                    def runninpegaAdmin2Servers = pegaAdmin2Servers - stoppedpegaAdmin2Servers 
                    
                    if (runninpegaAdmin2Servers) {
                        echo "Stopping the following Pega Admin instances: ${runninpegaAdmin2Servers.join(', ')}"
                        sh "aws ec2 stop-instances --instance-ids ${runninpegaAdmin2Servers.join(' ')}"
                        // Wait for all first instances to stop
                        waitForInstancesToStop(runninpegaAdmin2Servers,600,10)
                    }
                    // Report which first instances were already stopped
                    if (stoppedpegaAdmin2Servers) {
                        echo "The following second Pega Admin instances were already stopped: ${stoppedpegaAdmin2Servers.join(', ')}"
                    } 
                    sleep(5)

                    def stoppedpegaAdmin3Servers = listAlreadyStopped(pegaAdmin3Servers)
                    //def stoppedpegaAdmin3Servers = areInstancesStopped(pegaAdmin3Servers)
                    def runninpegaAdmin3Servers = pegaAdmin3Servers - stoppedpegaAdmin3Servers 
                    
                    if (runninpegaAdmin3Servers) {
                        echo "Stopping the following Pega Admin instances: ${runninpegaAdmin3Servers.join(', ')}"
                        sh "aws ec2 stop-instances --instance-ids ${runninpegaAdmin3Servers.join(' ')}"
                        // Wait for all first instances to stop
                        waitForInstancesToStop(runninpegaAdmin3Servers,600,10)
                    }
                        // Report which first instances were already stopped
                    if (stoppedpegaAdmin3Servers) {
                        echo "The following third Pega Admin instances were already stopped: ${stoppedpegaAdmin3Servers.join(', ')}"
                    } 

                 }
            }
        }

        stage('Stop Windows Instances') {
            when {
                expression { params.Platform == 'Windows' || params.Platform == 'All' }
            }
            steps {
                script {
                    echo 'Stopping Windows Instances...'
                    // Add logic for stopping Windows instances
                    def windowsInstances = readFile('WindowsInstances.txt').split('\n').collect { it.trim() }
                    // Define Windows instance IDs
                        
                    // Function to check if instances are stopped
                    def areInstancesStopped = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        return state.split('\n').every { it == 'stopped' }
                    }

                                    
                    def listAlreadyStopped = { ids ->
                        def states = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State[].Name' --output text", returnStdout: true).trim().split()
                        return ids.findAll { id ->
                            def index = ids.indexOf(id)
                            return states[index] == 'stopped'
                        }
                    }
                    
                    // Function to wait until all specified instances are stopped
                    def waitForInstancesToStop = { ids, maxWaitTime = 600, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                            def states = state.split("\\s+")
                            echo "Instance states: ${states}"
                            
                            // Check each state individually and log
                            def allStopped = true
                            states.each { instanceState ->
                                echo "Instance state: ${instanceState}"
                                if (instanceState != 'stopped') {
                                    allStopped = false
                                }
                            }
                            if (allStopped) {
                                echo "All instances are now stopped."
                                return true
                            } else {
                                echo "Not all instances are stopped yet."
                            }
                            sleep(checkInterval) // Wait before checking again
                            waited += checkInterval
                        }
                        error "Timeout: Not all instances are stopped after ${maxWaitTime} seconds."
                    }       
                    def stoppedWindowsInstances = listAlreadyStopped(windowsInstances)
                    //def stoppedWindowsInstances = areInstancesStopped(windowsInstances)
                    def runningWindowsInstances = windowsInstances - stoppedWindowsInstances
                    
                    if (stoppedWindowsInstances) {
                        echo "These Windows instances were already stopped: ${stoppedWindowsInstances.join(', ')}"
                    }
                    if (runningWindowsInstances) {
                        echo "These Windows instances were already running: ${runningWindowsInstances.join(', ')}"
                    }
                    
                    //echo " here are the ${runningWindowsInstances.join(' ')}"
                    
                    if (runningWindowsInstances) {
                        sh "aws ec2 stop-instances --instance-ids ${runningWindowsInstances.join(' ')}"
                        waitForInstancesToStop(runningWindowsInstances,600,15)
                    }

                    if (stoppedWindowsInstances) {
                        echo "The following Windows instances were already stopped: ${stoppedWindowsInstances.join(', ')}"
                    }
                }
            }
        }
        stage('Stop Database Servers') {
            when {
                expression { params.Platform == 'Linux' || params.Platform == 'All' }
            }
            steps {
                script {
                    echo 'Stopping Database Servers...'
                    def firstDatabase = readFile('FirstDatabase.txt').split('\n').collect { it.trim() } //First DB instances for Lo   // Define database instance IDs per environment
 
                    def secondDatabase = readFile('SecondDatabase.txt').split('\n').collect { it.trim() }
             
                    // Function to check if instances are running
                    def areInstancesRunning = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        return state.split('\n').every { it == 'running' }
                    }
                    // Function to check if instances are stopped
                    def areInstancesStopped = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        return state.split('\n').every { it == 'stopped' }
                    }
                     // Function to list already stopped instances

                    def listAlreadyStopped = { ids ->
                        def states = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State[].Name' --output text", returnStdout: true).trim().split()
                        return ids.findAll { id ->
                             def index = ids.indexOf(id)
                            return states[index] == 'stopped'
                        }
                    }

                    def waitForInstancesToStop = { ids, maxWaitTime = 600, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                            def states = state.split("\\s+")
                            echo "Instance states: ${states}"
                            
                            // Check each state individually and log
                            def allStopped = true
                            states.each { instanceState ->
                                echo "Instance state: ${instanceState}"
                                if (instanceState != 'stopped') {
                                    allStopped = false
                                }
                            }
                            if (allStopped) {
                                echo "All instances are now stopped."
                                return true
                            } else {
                                echo "Not all instances are stopped yet."
                            }
                            sleep(checkInterval) // Wait before checking again
                            waited += checkInterval
                        }
                        error "Timeout: Not all instances are stopped after ${maxWaitTime} seconds."
                    }       

                    ///////////////////////////////////////////////////////////////////////////////////////////////////
                    // Stop the first instances of each environment simultaneously
                    def stoppedfirstDatabase = listAlreadyStopped(firstDatabase)
                    //def stoppedfirstDatabase = areInstancesStopped(firstDatabase)
                    def runningfirstDatabase = firstDatabase - stoppedfirstDatabase  
                    if (runningfirstDatabase) {
                        echo "Stopping the following primary Database instances: ${runningfirstDatabase.join(', ')}"
                        sh "aws ec2 stop-instances --instance-ids ${runningfirstDatabase.join(' ')}"
                        // Wait for all first instances to stop
                        waitForInstancesToStop(runningfirstDatabase,600,10)
                    }
                    // Report which first instances were already stopped
                    if (stoppedfirstDatabase) {
                        echo "The following first Database instances were already stopped: ${stoppedfirstDatabase.join(', ')}"
                    } 
                    
                    sleep (23)

                    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                    def stoppedsecondDatabase = listAlreadyStopped(secondDatabase)
                    //def stoppedsecondDatabase = areInstancesStopped(secondDatabase)
                    def runninsecondDatabase = secondDatabase - stoppedsecondDatabase 
                    if (runninsecondDatabase) {
                        echo "Stopping the following second Database instances: ${runninsecondDatabase.join(', ')}"
                        sh "aws ec2 stop-instances --instance-ids ${runninsecondDatabase.join(' ')}"
                        // Wait for all first instances to stop
                        waitForInstancesToStop(runninsecondDatabase,600,10)
                    }
                    // Report which first instances were already stopped
                    if (stoppedsecondDatabase) {
                        echo "The following second Database instances were already stopped: ${stoppedsecondDatabase.join(', ')}"
                    } 
                }
            }
        }      
        stage('Confirm to proceed to start'){
            steps {
                script {
                    // Human intervention after confirming second instances
                        input(message: "Please press proceed if you want are ready to start the instances.")
                    }
                }
        }
        stage('Start Database Servers') {
            when {
                expression { params.Platform == 'Linux' || params.Platform == 'All' }
             }
             steps {
                script {
                    echo 'Starting Database Servers...'

                    def firstDatabase = readFile('FirstDatabase.txt').split('\n').collect { it.trim() } 
                    def secondDatabase = readFile('SecondDatabase.txt').split('\n').collect { it.trim() }

                    def areInstancesRunning = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        return state.split('\n').every { it == 'running' }
                    }
                    // Function to check if an instance is operational
                     def isInstanceOperational = { instanceId, maxWaitTime = 300, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def status = sh(script: "aws ec2 describe-instance-status --instance-ids ${instanceId} --query 'InstanceStatuses[0].{InstanceState:InstanceState.Name,SystemStatus:SystemStatus.Status,InstanceStatus:InstanceStatus.Status}' --output json", returnStdout: true)
                            // Debug output to check status received
                            echo "Status for instance ${instanceId}: ${status}"
                            // Check if the status is empty
                            if (!status || status.trim() == 'null'){
                                echo "Instance ${instanceId} is still initializing or not available."
                            } else if (status && status != 'null') {
                                def instanceStatus = new groovy.json.JsonSlurper().parseText(status) // Use JsonSlurper for parsing
                                // Check if instance is running and both system and instance statuses are ok
                                if (instanceStatus && instanceStatus.InstanceState && instanceStatus.InstanceState == 'running' && instanceStatus.SystemStatus == 'ok' && instanceStatus.InstanceStatus == 'ok') {
                                    echo " expected states met"
                                    return true // Instance is operational
                                }
                            } 
                            sleep(checkInterval) // Wait before checking again
                            waited += checkInterval // Increment waited time
                        }
                        error "Timeout: Instance ${instanceId} is not operational after ${maxWaitTime} seconds."
                    }
                    // Function to wait until all specified instances are running
                    def waitForInstancesToStart = { ids, maxWaitTime = 600, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def allOperational = true // Flag to check if all instances are operational
                            for (id in ids) {
                                if (!isInstanceOperational(id,300,15)) {
                                   allOperational = false // If any instance is not operational, set the flag to false
                                   echo "Instance ${instanceId} did not start successfully."
                                }
                            }
                            if (allOperational) {
                                return true // All instances are operational
                            }
                            sleep(checkInterval) // Wait before checking again
                             waited += checkInterval
                        }
                        error "Timeout: Not all instances are started after ${maxWaitTime} seconds."
                    }

                    // Start the first instances of each environment simultaneously
                    if (firstDatabase) {
                        echo "Starting the following primary Database instances: ${firstDatabase.join(', ')}"
                        sh "aws ec2 start-instances --instance-ids ${firstDatabase.join(' ')}"
                
                        // Wait for all first instances to be fully operational
                        waitForInstancesToStart(firstDatabase,600, 15)
                    }
                    sleep(10)
                    // Start the second instances of each environment if they exist
                    if (secondDatabase) {
                        echo "Starting the following second Database instances: ${secondDatabase.join(', ')}"
                        sh "aws ec2 start-instances --instance-ids ${secondDatabase.join(' ')}"

                        // Wait for all second instances to be fully operational
                        waitForInstancesToStart(secondDatabase,600, 15)
                    }
                    echo " waiting 30 second before starting Pega servers"
                    sleep 30
                }
            }
        }
        stage('Sleep 15sec- before Pegastarts'){
            steps {
                script {
                    sleep(8)
                }
            }
        }
        stage('Start Pega Admin Servers') {
            when {
                expression { params.Platform == 'Linux' || params.Platform == 'All' }
             }
            steps {
                script {
                    echo 'Starting Pega Admin Servers...'

                    def pegaSercoServers = readFile('PagaAdminSerco.txt').split('\n').collect { it.trim() }// Pega Admin Serco for Low Env instances-dev-pro-imp   
                    def pegaAdmin2Servers = readFile('PagaAdmin2.txt').split('\n').collect { it.trim() }// Pega Admin2 for Low Env instances
                    def pegaAdmin3Servers = readFile('PagaAdmin3.txt').split('\n').collect { it.trim() }// Pega Admin3 for Low Env instances

                    // Function to check if instances are running
                    def areInstancesRunning = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                        return state.split('\n').every { it == 'running' }
                    }
                    // Function to check if an instance is operational
                    def isInstanceOperational = { instanceId, maxWaitTime = 300, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def status = sh(script: "aws ec2 describe-instance-status --instance-ids ${instanceId} --query 'InstanceStatuses[0].{InstanceState:InstanceState.Name,SystemStatus:SystemStatus.Status,InstanceStatus:InstanceStatus.Status}' --output json", returnStdout: true)
                            // Debug output to check status received
                            echo "Status for instance ${instanceId}: ${status}"
                            // Check if the status is empty
                            if (!status || status.trim() == 'null'){
                                echo "Instance ${instanceId} is still initializing or not available."
                            } else if (status && status != 'null') {
                                def instanceStatus = new groovy.json.JsonSlurper().parseText(status) // Use JsonSlurper for parsing
                                // Check if instance is running and both system and instance statuses are ok
                                if (instanceStatus && instanceStatus.InstanceState && instanceStatus.InstanceState == 'running' && instanceStatus.SystemStatus == 'ok' && instanceStatus.InstanceStatus == 'ok') {
                                    echo " expected states met"
                                    return true // Instance is operational
                                }
                            } 
                            sleep(checkInterval) // Wait before checking again
                            waited += checkInterval // Increment waited time
                        }
                        error "Timeout: Instance ${instanceId} is not operational after ${maxWaitTime} seconds."
                    }
   
                   // Function to wait until all specified instances are running
                    def waitForInstancesToStart = { ids, maxWaitTime = 600, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def allOperational = true // Flag to check if all instances are operational
                            for (id in ids) {
                                if (!isInstanceOperational(id,300,15)) {
                                   allOperational = false // If any instance is not operational, set the flag to false
                                   echo "Instance ${instanceId} did not start successfully."
                                }
                            }
                            if (allOperational) {
                                return true // All instances are operational
                            }
                            sleep(checkInterval) // Wait before checking again
                             waited += checkInterval
                        }
                        error "Timeout: Not all instances are started after ${maxWaitTime} seconds."
                    }

                    // Start all first instances of Pega Admin servers simultaneously
                    echo "Starting the following primary Pega Admin instances: ${pegaSercoServers.join(', ')}"
                    sh "aws ec2 start-instances --instance-ids ${pegaSercoServers.join(' ')}"
            
                    // Wait for all first instances to be fully operational
                    waitForInstancesToStart(pegaSercoServers,600,15)

                    // Human intervention after confirming first instances
                    input(message: "Check all first Pega Admin instances for all environments and confirm they are operational before proceeding.")

                    // Start second instances if they exist
                    if (pegaAdmin2Servers) {
                        echo "Starting the following second Pega Admin instances: ${pegaAdmin2Servers.join(', ')}"
                        sh "aws ec2 start-instances --instance-ids ${pegaAdmin2Servers.join(' ')}"

                        // Wait for all second instances to be fully operational
                        waitForInstancesToStart(pegaAdmin2Servers,600,15)

                        // Human intervention after confirming second instances
                        input(message: "Check all second Pega Admin instances for all environments and confirm they are operational before proceeding.")
                    }

                    // Start third instances if they exist
                    echo "Starting the following third Pega Admin instances: ${pegaAdmin3Servers.join(', ')}"
                    sh "aws ec2 start-instances --instance-ids ${pegaAdmin3Servers.join(' ')}"

                    // Wait for all third instances to be fully operational
                    waitForInstancesToStart(pegaAdmin3Servers,600,15)

                    // Human intervention after confirming third instances
                    input(message: "Check all third Pega Admin instances for all environments and confirm they are operational before proceeding.")
                    
                 }
             }
        }

        stage('Start Linux Instances') {
            when {
                expression { params.Platform == 'Linux' || params.Platform == 'All' }
                }
            
            steps {
                script {
                    echo 'Starting Linux Instances...'
                    def linuxInstances = readFile('LinuxInstances.txt').split('\n').collect { it.trim() }
                    // Function to check if instances are running
                    def areInstancesRunning = { ids ->
                        def state = sh(script: "aws ec2 describe-instances --instance-ids ${ids.join(' ')} --query 'Reservations[].Instances[].State.Name' --output text", returnStdout: true).trim()
                    return state.split('\n').every { it == 'running' }
                    }
                     // Function to wait until all specified instances are running
                    def waitForInstancesToStart = { ids, maxWaitTime = 600, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def runningInstances = ids.findAll { areInstancesRunning([it]) } // Get running instances
                            echo "Currently running instances: ${runningInstances.join(', ')}"
                            if (runningInstances.size() == ids.size()) {
                                return true // All instances are operational
                            }
                            sleep(checkInterval) // Wait before checking again
                            waited += checkInterval
                         }
                        error "Timeout: Not all instances are started after ${maxWaitTime} seconds."
                    }
                    echo "Starting the following Windows instances: ${linuxInstances.join(', ')}"

                    sh "aws ec2 start-instances --instance-ids ${linuxInstances.join(' ')}"
                    waitForInstancesToStart(linuxInstances,600, 15) // Ensure all instances are fully operational
                }
            }
        }
        
        stage('Start Windows Instances') {
            when {
                expression { params.Platform == 'Windows' || params.Platform == 'All' || params.ResumeFailure == 'StartLinux' }
            }
            steps {
                script {
                    echo 'Starting Windows Instances...'
                    def windowsInstances = readFile('WindowsInstances.txt').split('\n').collect { it.trim() }
                     // Define Windows instance IDs
                    // Function to check if an instance is operational
                    def isInstanceOperational = { instanceId, maxWaitTime = 300, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def status = sh(script: "aws ec2 describe-instance-status --instance-ids ${instanceId} --query 'InstanceStatuses[0].{InstanceState:InstanceState.Name,SystemStatus:SystemStatus.Status,InstanceStatus:InstanceStatus.Status}' --output json", returnStdout: true)
                            // Debug output to check status received
                            echo "Status for instance ${instanceId}: ${status}"
                            // Check if the status is empty
                            if (!status || status.trim() == 'null'){
                                echo "Instance ${instanceId} is still initializing or not available."
                            } else if (status && status != 'null') {
                                def instanceStatus = new groovy.json.JsonSlurper().parseText(status) // Use JsonSlurper for parsing
                                // Check if instance is running and both system and instance statuses are ok
                                if (instanceStatus && instanceStatus.InstanceState && instanceStatus.InstanceState == 'running' && instanceStatus.SystemStatus == 'ok' && instanceStatus.InstanceStatus == 'ok') {
                                    echo " expected states met"
                                    return true // Instance is operational
                                }
                            } 
                            sleep(checkInterval) // Wait before checking again
                            waited += checkInterval // Increment waited time
                        }
                        error "Timeout: Instance ${instanceId} is not operational after ${maxWaitTime} seconds."
                    }
                    // Function to wait until all specified instances are running
                    def waitForInstancesToStart = { ids, maxWaitTime = 600, checkInterval = 15 ->
                        def waited = 0
                        while (waited < maxWaitTime) {
                            def allOperational = true // Flag to check if all instances are operational
                            for (id in ids) {
                                if (!isInstanceOperational(id,300,15)) {
                                   allOperational = false // If any instance is not operational, set the flag to false
                                   echo "Instance ${instanceId} did not start successfully."
                                }
                            }
                            if (allOperational) {
                                return true // All instances are operational
                            }
                            sleep(checkInterval) // Wait before checking again
                             waited += checkInterval
                        }
                        error "Timeout: Not all instances are started after ${maxWaitTime} seconds."
                    }
                    echo "Starting the following Windows instances: ${windowsInstances.join(', ')}"
                    sh "aws ec2 start-instances --instance-ids ${windowsInstances.join(' ')}"
                    waitForInstancesToStart(windowsInstances, 600, 15) // Ensure all instances are fully operational
                    // Confirm all instances are running
                    echo "All Windows instances are now running."
                }
            }
        }
    }
}
