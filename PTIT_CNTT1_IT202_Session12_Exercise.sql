drop database if exists socialnetworkdb;
create database socialnetworkdb;
use socialnetworkdb;

-- i. tạo bảng dữ liệu

-- bảng users: lưu thông tin người dùng
create table users (
    user_id int primary key auto_increment,        -- mã người dùng
    username varchar(50) unique not null,           -- tên đăng nhập
    password varchar(255) not null,                 -- mật khẩu
    email varchar(100) unique not null,             -- email
    created_at datetime default current_timestamp   -- ngày tạo
);

-- bảng posts: lưu bài viết
create table posts (
    post_id int primary key auto_increment,         -- mã bài viết
    user_id int,                                    -- người đăng bài
    content text not null,                          -- nội dung
    created_at datetime default current_timestamp,  -- thời gian đăng
    foreign key (user_id) references users(user_id)
);

-- bảng comments: lưu bình luận
create table comments (
    comment_id int primary key auto_increment,      -- mã bình luận
    post_id int,                                    -- bài viết
    user_id int,                                    -- người bình luận
    content text not null,                          -- nội dung bình luận
    created_at datetime default current_timestamp,  -- thời gian
    foreign key (post_id) references posts(post_id),
    foreign key (user_id) references users(user_id)
);

-- bảng friends: quản lý kết bạn
create table friends (
    user_id int,                                    -- người gửi lời mời
    friend_id int,                                  -- người nhận lời mời
    status varchar(20) check (status in ('pending','accepted')), -- trạng thái
    foreign key (user_id) references users(user_id),
    foreign key (friend_id) references users(user_id)
);

-- bảng likes: quản lý lượt thích bài viết
create table likes (
    user_id int,                                    -- người thích
    post_id int,                                    -- bài viết
    foreign key (user_id) references users(user_id),
    foreign key (post_id) references posts(post_id)
);

-- dữ liệu mẫu

insert into users(username,password,email) values
('an','123','an@gmail.com'),
('binh','123','binh@gmail.com'),
('hoa','123','hoa@gmail.com');

-- ii. mức độ trung bình

-- view hiển thị thông tin công khai của người dùng
create or replace view vw_public_users as
select user_id, username, created_at
from users;

-- index tối ưu tìm kiếm người dùng theo username
create index idx_users_username on users(username);


-- iii. mức độ khá

-- procedure đăng bài viết
drop procedure if exists sp_create_post;
delimiter $$

create procedure sp_create_post(
    in p_user_id int,
    in p_content text
)
begin
    -- kiểm tra người dùng tồn tại
    if exists (select 1 from users where user_id = p_user_id) then
        insert into posts(user_id, content)
        values (p_user_id, p_content);
    else
        signal sqlstate '45000'
        set message_text = 'người dùng không tồn tại';
    end if;
end$$
delimiter ;

-- gọi thử procedure đăng bài
call sp_create_post(1,'hello database');
call sp_create_post(2,'learning sql is fun');

-- view hiển thị các bài viết trong 7 ngày gần nhất
create or replace view vw_recent_posts as
select *
from posts
where created_at >= now() - interval 7 day;

-- index tối ưu truy vấn bài viết theo người dùng và thời gian
create index idx_posts_user on posts(user_id);
create index idx_posts_user_date on posts(user_id, created_at);

-- procedure thống kê số bài viết của người dùng
drop procedure if exists sp_count_posts;
delimiter $$

create procedure sp_count_posts(
    in p_user_id int,
    out p_total int
)
begin
    select count(*) into p_total
    from posts
    where user_id = p_user_id;
end$$
delimiter ;

-- gọi procedure thống kê
call sp_count_posts(1,@total_posts);
select @total_posts as tong_bai_viet;


-- iv. mức độ giỏi

-- view quản lý người dùng đang hoạt động (có with check option)
create or replace view vw_active_users as
select *
from users
where created_at is not null
with check option;

-- procedure gửi lời mời kết bạn
drop procedure if exists sp_add_friend;
delimiter $$

create procedure sp_add_friend(
    in p_user_id int,
    in p_friend_id int
)
begin
    -- không cho kết bạn với chính mình
    if p_user_id = p_friend_id then
        signal sqlstate '45000'
        set message_text = 'không thể kết bạn với chính mình';
    else
        insert into friends values (p_user_id, p_friend_id,'pending');
    end if;
end$$
delimiter ;

-- procedure gợi ý bạn bè
drop procedure if exists sp_suggest_friends;
delimiter $$

create procedure sp_suggest_friends(
    in p_user_id int,
    inout p_limit int
)
begin
    select user_id, username
    from users
    where user_id <> p_user_id
    limit p_limit;
end$$
delimiter ;

-- index tối ưu thống kê lượt thích
create index idx_likes_post on likes(post_id);

-- view top 5 bài viết có nhiều lượt thích nhất
create or replace view vw_top_posts as
select post_id, count(*) as total_likes
from likes
group by post_id
order by total_likes desc
limit 5;

-- v. mức độ xuất sắc


-- procedure thêm bình luận cho bài viết
drop procedure if exists sp_add_comment;
delimiter $$

create procedure sp_add_comment(
    in p_user_id int,
    in p_post_id int,
    in p_content text
)
begin
    -- kiểm tra người dùng
    if not exists (select 1 from users where user_id = p_user_id) then
        signal sqlstate '45000'
        set message_text = 'người dùng không tồn tại';
    -- kiểm tra bài viết
    elseif not exists (select 1 from posts where post_id = p_post_id) then
        signal sqlstate '45000'
        set message_text = 'bài viết không tồn tại';
    else
        insert into comments(post_id,user_id,content)
        values (p_post_id,p_user_id,p_content);
    end if;
end$$
delimiter ;

-- view hiển thị bình luận của bài viết
create or replace view vw_post_comments as
select 
    c.content as noi_dung_binh_luan,
    u.username as ten_nguoi_binh_luan,
    c.created_at as thoi_gian
from comments c
join users u on c.user_id = u.user_id;

-- procedure ghi nhận lượt thích bài viết
drop procedure if exists sp_like_post;
delimiter $$

create procedure sp_like_post(
    in p_user_id int,
    in p_post_id int
)
begin
    -- kiểm tra đã thích hay chưa
    if exists (
        select 1 from likes
        where user_id = p_user_id and post_id = p_post_id
    ) then
        signal sqlstate '45000'
        set message_text = 'bài viết đã được thích trước đó';
    else
        insert into likes values (p_user_id,p_post_id);
    end if;
end$$
delimiter ;

-- view thống kê số lượt thích của bài viết
create or replace view vw_post_likes as
select post_id, count(*) as total_likes
from likes
group by post_id;

-- procedure tìm kiếm người dùng và bài viết
drop procedure if exists sp_search_social;
delimiter $$

create procedure sp_search_social(
    in p_option int,
    in p_keyword varchar(100)
)
begin
    -- tìm kiếm người dùng theo username
    if p_option = 1 then
        select * from users
        where username like concat('%',p_keyword,'%');
    -- tìm kiếm bài viết theo nội dung
    elseif p_option = 2 then
        select * from posts
        where content like concat('%',p_keyword,'%');
    else
        signal sqlstate '45000'
        set message_text = 'tùy chọn không hợp lệ';
    end if;
end$$
delimiter ;

-- kiểm tra chức năng tìm kiếm
call sp_search_social(1,'an');
call sp_search_social(2,'database');
