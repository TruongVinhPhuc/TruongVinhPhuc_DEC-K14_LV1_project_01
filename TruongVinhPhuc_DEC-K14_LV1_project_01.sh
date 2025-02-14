#!/bin/bash

file=/home/phuc/Desktop/tmdb-movies.csv
cleaned_format_file=/home/phuc/Desktop/cleaned_format.csv

# Combine end-line character of a record
awk -F"," '
function type(x) {
    if (x ~ /^[0-9][0-9]*$/) {
        return "int";
    } 
    return "string";
}
    NR==1{print;next;}
{
    if (type($1) == "string") {
        combined_line = prev_line " " $0;

        prev_line = combined_line;
    } else {
        if (prev_line != "") {
            print prev_line;  # In dòng trước nếu dòng hiện tại là record đúng
        }
        prev_line = $0;  # Lưu dòng hiện tại
    }
}

END {
    if (prev_line != "") {
        print prev_line;  # In dòng cuối cùng nếu còn sót
    }
}' $file | uniq > $cleaned_format_file

# Modify the release_date to the correct format to sort
echo "$(awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '
NR==1{print;next;}
{
  split($16, d, "/")
  day = d[2]
  month = d[1]
  if ( length(day) == 1){
     day = "0" day
  }
  if ( length(month) == 1){
     month = "0" month
  }
  $16 = $19"-"month"-"day
}1' $cleaned_format_file
)" > $cleaned_format_file


#1. Sắp xếp các bộ phim theo ngày phát hành giảm dần rồi lưu ra một file mới
awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '
function binary_search(array, value, low, high) {
    while (low <= high) {
        mid = int((low + high) / 2);
        if (value < array[mid]) {
            high = mid - 1;
        } else {
            low = mid + 1;
        }
    }
    return low;
}
NR==1{print;n++;next;}
{
    data[NR] = $0;
    dates[NR] = $16;
    n++;
}
END {
    for (i = 1; i <= n; i++) {
        current_date = dates[i];
        current_data = data[i];
        pos = binary_search(dates, current_date, 1, i - 1);
        for (j = i; j > pos; j--) {
            dates[j] = dates[j - 1];
            data[j] = data[j - 1];
        }
        
        dates[pos] = current_date;
        data[pos] = current_data;
    }
    for (i = 1; i <= n; i++) {
        print data[n - i + 1];
    }
}' $cleaned_format_file > /home/phuc/Desktop/sorted_date.csv
#2. Lọc ra các bộ phim có đánh giá trung bình trên 7.5 rồi lưu ra một file mới
awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '
function type(x) {
    if (x ~ /^[0-9][0-9]*$/) {
        return "int";
    }
    if (x ~ /^[0-9]{1,2}\/[0-9]{1,2}\/[0-9]{2,4}$/) {
        return "date";
    }
    return "string";
}

{
    if ($18 > 7.5){
    	print $0
    }
}' $cleaned_format_file > /home/phuc/Desktop/high_rated.csv


#3. Tìm ra phim nào có doanh thu cao nhất và doanh thu thấp nhất
awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '
NR==1{next;}
NR==2{min = $21; max = $21}
{
    if ($21 < min) {
    	min_record = $0
    	min = $21
    }
    if ($21 > max){
    	max_record = $0
    	max = $21
    }
}
END {
    print "Movie with max revenue: " max_record;
    print "Movie with min revenue: " min_record;
}' $cleaned_format_file

#4. Tính tổng doanh thu tất cả các bộ phim
awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '
{
    total += $21;
}

END {
    print "Total revenue: " total;
}' $cleaned_format_file

#5. Top 10 bộ phim đem về lợi nhuận cao nhất
awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '
NR==1{$0 = "profit," $0; print $0; next;}
{
    profit = $21 - $20
    $0 = profit "," $0;
}
END {
}1' $cleaned_format_file | sort -t, -k 1,1 | head -n 10

#6. Đạo diễn nào có nhiều bộ phim nhất và diễn viên nào đóng nhiều phim nhất
awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '
NR==1{director_max_count = 0; actor_max_count = 0; next;}
{
    split($9, director_tmp, "|")
    split($7, actor_tmp, "|")
    for (i in director_tmp) {
    	director_count[director_tmp[i]]++;
    	if (director_count[director_tmp[i]] > director_max_count) {
    	   director_max_count = director_count[director_tmp[i]];
    	   delete director_max;
    	   num_of_director = 1;
    	   director_max[num_of_director] = director_tmp[i];
    	}
    	else if (director_count[director_tmp[i]] == director_max_count){
	   num_of_director++;
	   director_max[num_of_director] = director_tmp[i];
    	}
    }
    for (i in actor_tmp) {
    	actor_count[actor_tmp[i]]++;
    	if (actor_count[actor_tmp[i]] > actor_max_count) {
    	   actor_max_count = actor_count[actor_tmp[i]];
    	   delete actor_max;
    	   num_of_actor = 1;
    	   actor_max[num_of_actor] = actor_tmp[i];
    	}
    	else if (actor_count[actor_tmp[i]] == actor_max_count){
	   num_of_actor++;
	   actor_max[num_of_actor] = actor_tmp[i];
    	}    	
    }
}
END {
    print "Directors with most movies (with "director_max_count" movies) involved are: ";
    for (i in director_max){
    	print director_max[i];
    }
    print "Actor with most movies (with "actor_max_count" movies) involved are: ";
    for (i in actor_max){
    	print actor_max[i];
    }    
}' $cleaned_format_file

#7. Thống kê số lượng phim theo các thể loại. Ví dụ có bao nhiêu phim thuộc thể loại Action, bao nhiêu thuộc thể loại Family, ….
awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' '
NR==1{next;}
{
    split($14, movie_genres, "|");
    for (i in movie_genres) {
    	genres[movie_genres[i]]++;
    }
}
END {
   for (genre in genres) {
   	print "Genre " genre " have " genres[genre] " movies with this genre"
   }
}' $cleaned_format_file

#8. Idea của bạn để có thêm những phân tích cho dữ liệu?
# Có thể thống kê thể loại được ưa chuộng (tìm lợi nhuận theo thể loại)
# Có thể xem thử diễn viên nào được ưa thích nhất (tìm lợi nhuận của các bộ phim mà họ tham gia và so sánh với các diễn viên khác)
# Tương tự với diễn viên thì ta có thể xem xét tới yếu tố đạo diễn và công ty sản xuất nào hút khách nhất.
# Nếu dữ liệu được sử dụng cho pipeline học máy dự đoán phim thì giữ các yếu tố trên cùng với cleaning và EDA phase (outliers có thể không bỏ vì dữ liệu là hợp lí, thay thế các giá trị rỗng theo data quality rule hoặc sử dụng mean/mode hoặc nằm trong khoảng tứ phân vị


