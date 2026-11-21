param(
    [switch]$Rebase
)

$ErrorActionPreference = "Stop"

function Step($text) { Write-Host "== $text" -ForegroundColor Cyan }

if (-not (git remote)) { throw "当前目录不是 git 仓库" }
$remotes = git remote
if ($remotes -notcontains "upstream") {
    Step "添加 upstream 远端"
    git remote add upstream https://github.com/chen08209/FlClash.git
}

Step "抓取 upstream"
git fetch --prune --tags upstream main

Step "切换到 main"
git switch main

$behind = [int](git rev-list --count "HEAD..upstream/main")
$ahead = [int](git rev-list --count "upstream/main..HEAD")
Write-Host "落后 upstream $behind 个提交，领先 $ahead 个提交"

if ($behind -eq 0) {
    Write-Host "已是最新，无需同步" -ForegroundColor Green
    exit 0
}

if ($Rebase) {
    Step "rebase 到 upstream/main"
    try {
        git rebase upstream/main
    } catch {
        git rebase --abort
        throw "rebase 冲突，已中止。请手动处理：git rebase upstream/main"
    }
} elseif ($ahead -eq 0) {
    Step "快进合并"
    git merge --ff-only upstream/main
} else {
    Step "普通合并（保留本地提交）"
    try {
        git merge --no-edit upstream/main
    } catch {
        git merge --abort
        throw "合并冲突，已中止。请手动处理：git merge upstream/main"
    }
}

Step "推送到 fork"
git push origin main

Step "同步完成"
git log --oneline -3
