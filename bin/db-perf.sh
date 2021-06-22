
start_time="$(date -u +%s.%N)"
mysql -uroot -p${MYSQL_ROOT_PASSWORD} oscar < schedule-full.sql > /dev/null
end_time="$(date -u +%s.%N)"

elapsed="$(bc <<<"$end_time-$start_time")"
echo "Total of $elapsed seconds elapsed for process"


