export def "to test" [] {
  print "DEBUG: Script started 3"
  print $"in ($in)"
  each { |num| print $"DEBUG: ($num)"}
  # print $"in ($in)"
}
