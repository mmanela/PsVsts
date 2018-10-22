# Functions and variables used for communication with AzureDevOps


$script:cached_HttpClient = $null
$script:cached_accountProjectMap = @{}

$script:projectsUrl =         "https://{0}.visualstudio.com/defaultcollection/_apis/projects?api-version=1.0"
$script:gitReposUrl =         "https://{0}.visualstudio.com/defaultcollection/{1}/_apis/git/repositories?api-version=1.0"
$script:identityUrl =         "https://{0}.visualstudio.com/defaultcollection/_api/_identity/CheckName?name={1}"
$script:pullRequestUrl =      "https://{0}.visualstudio.com/defaultcollection/_apis/git/repositories/{1}/pullRequests?api-version=1.0-preview.1"
$script:openPullRequestUrl =  "https://{0}.visualstudio.com/defaultcollection/{1}/_git/{2}/pullrequest/{3}"
$script:buildDefinitionsUrl = "https://{0}.visualstudio.com/defaultcollection/{1}/_apis/build/definitions?name={2}&type={3}&`$top=1&api-version=2.0"
$script:buildsUrlWithFilters ="https://{0}.visualstudio.com/defaultcollection/{1}/_apis/build/builds?definitions={2}&type={3}&`$top={4}&{5}api-version=2.0"
$script:codeCoverageUrl =     "https://{0}.visualstudio.com/defaultcollection/{1}/_apis/test/CodeCoverage?buildId={2}"
$script:buildArtifactUrl =    "https://{0}.visualstudio.com/defaultcollection/{1}/_apis/build/builds/{2}/artifacts?artifactName={3}&api-version=4.1"
$script:runQueryUrl =         "https://{0}.visualstudio.com/defaultcollection/{1}/_apis/wit/wiql?api-version=1.0"
$script:getWorkItemsUrl =     "https://{0}.visualstudio.com/defaultcollection/_apis/wit/workitems?ids={1}&fields=System.Id,System.Title,System.WorkItemType,System.AssignedTo,System.CreatedBy,System.ChangedBy,System.CreatedDate,System.ChangedDate,System.State&api-version=1.0"
$script:openWorkItemUrl=      "https://{0}.visualstudio.com/defaultcollection/_workitems/edit/{1}"

# Override urls to run against a local TFS server
if($PsAzureDevOps.OnPremiseMode) {
    $script:projectsUrl =         "http://{0}:8080/tfs/defaultcollection/_apis/projects?api-version=1.0"
    $script:gitReposUrl =         "http://{0}:8080/tfs/defaultcollection/{1}/_apis/git/repositories?api-version=1.0"
    $script:identityUrl =         "http://{0}:8080/tfs/defaultcollection/_api/_identity/CheckName?name={1}"
    $script:pullRequestUrl =      "http://{0}:8080/tfs/defaultcollection/_apis/git/repositories/{1}/pullRequests?api-version=1.0-preview.1"
    $script:openPullRequestUrl =  "http://{0}:8080/tfs/defaultcollection/{1}/_git/{2}/pullrequest/{3}"
    $script:buildDefinitionsUrl = "http://{0}:8080/tfs/defaultcollection/{1}/_apis/build/definitions?name={2}&type={3}&`$top=1&api-version=2.0"
    $script:buildsUrlWithFilters ="http://{0}:8080/tfs/defaultcollection/{1}/_apis/build/builds?definitions={2}&type={3}&`$top={4}&{5}api-version=2.0"
	$script:codeCoverageUrl =     "http://{0}:8080/tfs/defaultcollection/{1}/_apis/test/CodeCoverage?buildId={2}"
    $script:buildArtifactUrl =    "http://{0}:8080/tfs/defaultcollection/{1}/_apis/build/builds/{2}/artifacts?artifactName={3}&api-version=4.1"
    $script:runQueryUrl =         "http://{0}:8080/tfs/defaultcollection/{1}/_apis/wit/wiql?api-version=1.0"
    $script:getWorkItemsUrl=      "http://{0}:8080/tfs/defaultcollection/_apis/wit/workitems?ids={1}&fields=System.Id,System.Title,System.WorkItemType,System.AssignedTo,System.CreatedBy,System.ChangedBy,System.CreatedDate,System.ChangedDate,System.State&api-version=1.0"
    $script:openWorkItemUrl=      "http://{0}:8080/tfs/defaultcollection/_workitems/edit/{1}"
}

$script:stateExcludeFilterQueryPart = "AND ([System.State] NOT IN ({0}))"
$script:stateIncludeFilterQueryPart = "AND ([System.State] IN ({0}))"
$script:identityFilterQueryPart = " [{0}] = @me "
$script:getMyWorkItemsQuery  = "SELECT [System.Id]  
                               FROM WorkItems 
                               WHERE ([System.TeamProject] = @project)
                                     AND ([System.ChangedDate] > '{0}')  
                                     {1} 
                                     AND ({2}) 
                               ORDER BY [{3}] DESC,[System.Id] DESC"



function openWorkItemInBrowser($account, $workItemId) {
    $webWorkItemUrl = [System.String]::Format($script:openWorkItemUrl, $account, $workItemId)

    Start-Process $webWorkItemUrl
}

function getWorkItemsFromIds($account, $wiIds) {
    
    $wiIdString = $wiIds -join ","
    $workItemsUrl = [System.String]::Format($script:getWorkItemsUrl, $account, $wiIdString)
    $workItemsResult = getUrl $workItemsUrl    
    
    if($workItemsResult){
        return $workItemsResult.value
    }
}

function getWorkItemsFromQuery($account, $project, $query, $take) {

    $queryUrl = [System.String]::Format($script:runQueryUrl, $account, $project)

    $payload = @{
        "query" = $query
    }

    $queryResults = postUrl $queryUrl $payload

    if(-not $queryResults) {
        return $null
    }
    # The ids of the workitems in sorted order
    $resultIds = $queryResults.workItems.id | Select-Object -First $take

    if($resultIds) {
        $workItems = getWorkItemsFromIds $account $resultIds
         
        if($workItems) {

            # We need to sort the results by the query results since
            # work items rest call doesn't honor order
            $workItemMap = @{}
            $workItems | ForEach-Object { $workItemMap[$_.Id] = $_ }

            $sortedWorkItems = $resultIds | ForEach-Object { $workItemMap[$_] }
            return $sortedWorkItems

        }
    }

}

function getBuilds($account, $project, $definition, $type, $take, $filters) {
    
    $getBuildDefinitionUrl = [System.String]::Format($script:buildDefinitionsUrl, $account, $project, $definition, $type)
    $definitionResult = getUrl $getBuildDefinitionUrl
    if($definitionResult.value) {
        $getBuildUrl = [System.String]::Format($script:buildsUrlWithFilters, $account, $project, $definitionResult.value.id, $type, $take, $filters)
        $buildResults = getUrl $getBuildUrl

        if($buildResults) {
            return $buildResults.value
        }
    }

    return $null
}

function getBuildCodeCoverage($account, $project, $definition, $type) {
	$buildResult = getBuilds $account $project $definition $type 1 "status=completed&resultFilter=succeeded&"
	if ($buildResult) {
		$getCodeCoverageUrl = [System.String]::Format($script:codeCoverageUrl, $account, $project, $buildResult.id)
		$codeCoverageResults = getUrl $getCodeCoverageUrl
		
		if ($codeCoverageResults -and $codeCoverageResults.coverageData -and $codeCoverageResults.coverageData.coverageStats) {
            for ($ct = 0; $ct -lt $codeCoverageResults.coverageData.coverageStats.Length; $ct++) {
                $currentItem = $codeCoverageResults.coverageData.coverageStats[$ct]
                $currentItem | Add-Member 'coverage' ([math]::Round((100 * [int] $currentItem.covered[0]) / [int] $currentItem.total[0], 2))
                $currentItem | Add-Member 'build' $buildResult.buildNumber
            }
            return $codeCoverageResults.coverageData.coverageStats
		}
	}
	
	return $null
}

function getBuildArtifact($account, $project, $definition, $artifactName, $type) {
	$buildResult = getBuilds $account $project $definition $type 1 "status=completed&resultFilter=succeeded&"
	if ($buildResult) {
		$getBuildArtifactUrl = [System.String]::Format($script:buildArtifactUrl, $account, $project, $buildResult.id, $artifactName)
        $buildArtifactResults = getUrl $getBuildArtifactUrl

        if ($buildArtifactResults) {
            return $buildArtifactResults.resource
        }
    }

    return $null
}

function createRepo($account, $project, $repo) {
   $projectId = getProjectId $account $project
   $payload = @{
    "name" = $repoName
    "project" = @{ "id" = $projectId }
   }

    $url = [System.String]::Format($script:gitReposUrl, $account, $project)
    $repoResults = postUrl $url $payload

    if($repoResults) {
        return $repoResults
    }
}


function getRepos($account, $project) {

    $url = [System.String]::Format($script:gitReposUrl, $account, $project)
    $repoResults = getUrl $url

    if($repoResults) {
        return $repoResults.value
    }
    else {
        return $null
    }
}

function getRepoId($account, $project, $repository) {
    
    $repos = getRepos $account $project
    $repos = @($repos | Where-Object { $_.name -eq $repository })

    if($repos.Count -le 0){
        throw "Unable to find repository id for a repository named $repository"
    }

    return $repos[0].id
}


function getProjectId($account, $project) {
    
    # Check in the cache first for this account/project
    $projectId = getProjectIdFromCache $account $project

    # Check if a cache miss call the service and try again
    if(-not $projectId) {
        buildProjectMap $account
        $projectId = getProjectIdFromCache $account $project
    }

    if(-not $projectId) {
        throw "Unable to find the project $project in account $account"
    }

    return $projectId
}

function getProjectIdFromCache($account, $project) {
    
    # Check in the cache first for this account/project
    $projectId = $null
    $projectIdMap = $script:cached_accountProjectMap[$account]
    if($projectIdMap) {
        $projectId = $projectIdMap[$project]
    }

    return $projectId
}


function getProjects($account) {

    $url = [System.String]::Format($script:projectsUrl, $account)
    $projectResults = getUrl $url

    if($projectResults) {
        return $projectResults.value
    }
    else {
        return $null
    }
}

function getIdentityId($account, $name) {

    $url = [System.String]::Format($script:identityUrl, $account, $name)
    
    try {
        $identityResult = getUrl $url
    } catch {

    }

    if($identityResult -and $identityResult.Identity.TeamFoundationId) {
        return $identityResult.Identity.TeamFoundationId
    }
    else {
        Write-Warning "Unable to resolve the name $name"
        return $null
    }
}

function buildProjectMap($account) {
    
    $projectResults = getProjects $account

    if($projectResults) {
        $projectIdMap = @{}

        $projectResults | ForEach-Object { $projectIdMap[$_.name] = $_.id }

        $script:cached_accountProjectMap[$account] = $projectIdMap    
    }
    else {
        Write-Error "Unable to get projects for $account"
    }
}

function postUrl($urlStr, $payload) {
    
    Write-Progress -Activity "Making REST Call" -Status "POST $urlStr"
    
    traceMessage "POST $urlStr"

    $payloadString = ConvertTo-Json $payload
    traceMessage "payload: $payloadString"

    $content = New-Object System.Net.Http.StringContent($payloadString, [System.Text.Encoding]::UTF8, "application/json")

    $httpClient = getHttpClient
    $url = New-Object System.Uri($urlStr)
    $response = $httpClient.PostAsync($urlStr, $content).Result
    
    return processRestReponse $response
}

function getUrl($urlStr) {
    
    Write-Progress -Activity "Making REST Call" -Status "GET $urlStr"
    traceMessage "GET $urlStr"
    

    $httpClient = getHttpClient
    $url = New-Object System.Uri($urlStr)
    $response = $httpClient.GetAsync($urlStr).Result
    return processRestReponse $response
}

function processRestReponse($response) {
    
    $result = $response.Content.ReadAsStringAsync().Result


    try {
        if($result){
            $obj = ConvertFrom-Json $result


            traceMessage "REST RESPONSE: $obj"
        }
    }
    catch {

    }

    if($response.IsSuccessStatusCode) {
        return $obj
    }
    else {
        # TODO: Handle errors from the server
        throw "Recieved an error code of $($response.StatusCode) from the server"
    } 
}


function getHttpClient() {

    if($script:cached_HttpClient){
        return $script:cached_HttpClient;
    }

    $credentials = New-Object Microsoft.VisualStudio.Services.Client.VssClientCredentials
    $credentials.Storage = New-Object Microsoft.VisualStudio.Services.Client.VssClientCredentialStorage("VssApp", "VisualStudio")
    $requestSettings = New-Object Microsoft.VisualStudio.Services.Common.VssHttpRequestSettings
    $messageHandler = New-Object Microsoft.VisualStudio.Services.Common.VssHttpMessageHandler($credentials, $requestSettings)
    $httpClient = New-Object System.Net.Http.HttpClient($messageHandler)
    $httpClient.Timeout = [System.TimeSpan]::FromSeconds($PsAzureDevOps.TimeoutInSeconds)
    $httpClient.DefaultRequestHeaders.Add("User-Agent", "PsAzureDevOps/1.0");
    
    $script:cached_HttpClient = $httpClient

    return $httpClient
}
