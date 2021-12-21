{
  source: {
    name: "terrascan",
    url: "https://github.com/accurics/terrascan"
  },
  diagnostics: (.results.violations // {}) | map({
    message: .description,
    code: {
      value: .rule_id,
    } ,
    location: {
      path: .file,
      range: {
        start: {
          line: .line,
        },
      }
    },
    severity: (if .severity | startswith("HIGH") then
              "ERROR"
            elif .severity | startswith("MEDIUM") then
              "WARNING"
            elif .severity | startswith("LOW") then
              "INFO"
            else
              null
            end),
  })
}
