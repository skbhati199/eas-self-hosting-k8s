# PowerShell script to configure remote Kubernetes cluster
# This script will set up the Linux machine as either master or worker node

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("master", "worker", "status")]
    [string]$Mode,
    
    [string]$RemoteHost = "192.168.29.35",
    [string]$RemoteUser = "sonukumar",
    [string]$JoinCommand = ""
)

$ScriptPath = "./setup-remote-node.sh"

function Test-SSHConnection {
    param([string]$Host, [string]$User)
    
    Write-Host "🔍 Testing SSH connection to $User@$Host..."
    $result = Test-NetConnection -ComputerName $Host -Port 22
    
    if ($result.TcpTestSucceeded) {
        Write-Host "✅ SSH connection successful" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ SSH connection failed" -ForegroundColor Red
        return $false
    }
}

function Copy-SetupScript {
    param([string]$Host, [string]$User)
    
    Write-Host "📁 Copying setup script to remote host..."
    scp $ScriptPath "${User}@${Host}:~/setup-k8s.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Script copied successfully" -ForegroundColor Green
        # Make script executable
        ssh "${User}@${Host}" "chmod +x ~/setup-k8s.sh"
        return $true
    } else {
        Write-Host "❌ Failed to copy script" -ForegroundColor Red
        return $false
    }
}

function Install-KubernetesTools {
    param([string]$Host, [string]$User)
    
    Write-Host "🛠️ Installing Kubernetes tools on remote host..."
    ssh "${User}@${Host}" "~/setup-k8s.sh install"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Kubernetes tools installed successfully" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Failed to install Kubernetes tools" -ForegroundColor Red
        return $false
    }
}

function Initialize-Master {
    param([string]$Host, [string]$User)
    
    Write-Host "🎯 Initializing master node on remote host..."
    ssh "${User}@${Host}" "~/setup-k8s.sh master"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Master node initialized successfully" -ForegroundColor Green
        
        # Get the join command
        Write-Host "📋 Getting join command for worker nodes..."
        $joinCmd = ssh "${User}@${Host}" "sudo kubeadm token create --print-join-command"
        
        if ($joinCmd) {
            Write-Host "📝 Join command for worker nodes:" -ForegroundColor Yellow
            Write-Host $joinCmd -ForegroundColor Cyan
            
            # Save join command to file
            $joinCmd | Out-File -FilePath "./join-command.txt" -Encoding utf8
            Write-Host "💾 Join command saved to join-command.txt"
        }
        
        return $true
    } else {
        Write-Host "❌ Failed to initialize master node" -ForegroundColor Red
        return $false
    }
}

function Join-Worker {
    param([string]$Host, [string]$User, [string]$JoinCmd)
    
    if (-not $JoinCmd) {
        Write-Host "❌ Join command is required for worker mode" -ForegroundColor Red
        return $false
    }
    
    Write-Host "👷 Joining worker node to cluster..."
    ssh "${User}@${Host}" "~/setup-k8s.sh worker '$JoinCmd'"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Worker node joined successfully" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Failed to join worker node" -ForegroundColor Red
        return $false
    }
}

function Show-ClusterStatus {
    param([string]$Host, [string]$User)
    
    Write-Host "📊 Getting cluster status..."
    ssh "${User}@${Host}" "~/setup-k8s.sh status"
}

# Main execution
Write-Host "🚀 Configuring Kubernetes cluster on $RemoteUser@$RemoteHost" -ForegroundColor Blue
Write-Host "Mode: $Mode" -ForegroundColor Blue
Write-Host ""

# Test SSH connection
if (-not (Test-SSHConnection -Host $RemoteHost -User $RemoteUser)) {
    Write-Host "❌ Cannot connect to remote host. Please check:" -ForegroundColor Red
    Write-Host "   - SSH service is running on the remote host"
    Write-Host "   - You can SSH manually: ssh $RemoteUser@$RemoteHost"
    Write-Host "   - Network connectivity"
    exit 1
}

# Copy setup script
if (-not (Copy-SetupScript -Host $RemoteHost -User $RemoteUser)) {
    exit 1
}

# Install tools first (always required)
if (-not (Install-KubernetesTools -Host $RemoteHost -User $RemoteUser)) {
    exit 1
}

# Execute based on mode
switch ($Mode) {
    "master" {
        if (Initialize-Master -Host $RemoteHost -User $RemoteUser) {
            Write-Host "🎉 Master node setup complete!" -ForegroundColor Green
            Write-Host "📝 Next steps:"
            Write-Host "   1. Copy the kubeconfig from the master node to access the cluster"
            Write-Host "   2. Use the join command from join-command.txt to add worker nodes"
            Write-Host "   3. Deploy your EAS workloads to the new cluster"
        }
    }
    
    "worker" {
        if (-not $JoinCommand) {
            if (Test-Path "./join-command.txt") {
                $JoinCommand = Get-Content "./join-command.txt" -Raw
                $JoinCommand = $JoinCommand.Trim()
                Write-Host "📁 Using join command from join-command.txt"
            } else {
                Write-Host "❌ Join command not provided. Please either:" -ForegroundColor Red
                Write-Host "   - Use -JoinCommand parameter"
                Write-Host "   - Have join-command.txt file in current directory"
                exit 1
            }
        }
        
        if (Join-Worker -Host $RemoteHost -User $RemoteUser -JoinCmd $JoinCommand) {
            Write-Host "🎉 Worker node setup complete!" -ForegroundColor Green
        }
    }
    
    "status" {
        Show-ClusterStatus -Host $RemoteHost -User $RemoteUser
    }
}

Write-Host "" 
Write-Host "🔍 Final cluster status:"
Show-ClusterStatus -Host $RemoteHost -User $RemoteUser

