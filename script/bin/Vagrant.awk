BEGIN{
  FS = " "
}
$1 ~ /config\.vm\.define/{
  sub(/^:/,"",$2)
  printf("%-10s",$2)
}

$1 ~ /node\.vm\.network/{
  gsub(/\"/,"",$4)
  sub(/,$/,"",$4)
  print " " $4
}
