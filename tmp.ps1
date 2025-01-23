# 切换到 app/assets/i18n 目录
Push-Location app/assets/i18n

# 获取目录下的所有文件
$files = Get-ChildItem -File

# 遍历每个文件
foreach ($file in $files) {
    $filePath = $file.FullName

    # 尝试使用 git checkout --theirs 恢复文件
    try {
        git checkout --theirs $filePath
        Write-Host "Successfully restored: $filePath"
    }
    catch {
        # 如果文件在传入分支中不存在，则删除该文件
        Write-Host "File does not exist in theirs: $filePath"
        git rm $filePath
    }
}

# 返回原始目录
Pop-Location

