print("roslyn config loaded")
return {
    cmd = {
        "dotnet",
        "/home/andrei/.config/nvim/tools/Microsoft.CodeAnalysis.LanguageServer.linux-x64.5.3.0-1.25523.6_1/content/LanguageServer/linux-x64/Microsoft.CodeAnalysis.LanguageServer.dll",
        "--logLevel",
        "Information",
        '--extensionLogDirectory=' .. vim.fs.dirname(vim.lsp.get_log_path()),
        "--stdio",
    },
    root_markers = { "sln", "csproj", ".git" },
    filetypes = { "cs" },
}
