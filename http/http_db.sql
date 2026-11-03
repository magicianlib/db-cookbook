-- create database http_db;

--
-- http请求日志
--
drop table if exists public.http_request_logs;
create table public.http_request_logs
(
    id                uuid        not null
        constraint http_request_logs_pk
            primary key,
    user_id           text,
    biz_type          text,
    biz_no            text        not null,
    request_url       text,
    request_method    text,
    request_headers   text,
    request_body      text,
    response_code     integer,
    response_headers  text,
    response_body     text,
    biz_response_code text,
    is_success        integer,
    error_message     text,
    cost_time         integer,
    created_at        timestamptz not null,
    remark            text
);

comment on table public.http_request_logs is '网络请求日志';

comment on column public.http_request_logs.id is '主键ID';

comment on column public.http_request_logs.user_id is '请求用户';

comment on column public.http_request_logs.biz_type is '业务类型';

comment on column public.http_request_logs.biz_no is '业务单号';

comment on column public.http_request_logs.request_url is '请求URL';

comment on column public.http_request_logs.request_method is '请求方式';

comment on column public.http_request_logs.request_headers is '请求头';

comment on column public.http_request_logs.request_body is '请求报文';

comment on column public.http_request_logs.response_code is 'HTTP 状态码';

comment on column public.http_request_logs.response_headers is '响应头';

comment on column public.http_request_logs.response_body is '响应报文';

comment on column public.http_request_logs.biz_response_code is '业务响应码(如10001)';

comment on column public.http_request_logs.is_success is '是否成功(0否,1是)';

comment on column public.http_request_logs.error_message is '异常/报错信息(用于快速定位崩溃或报错)';

comment on column public.http_request_logs.cost_time is '耗时(毫秒 ms)';

comment on column public.http_request_logs.created_at is '创建时间';

comment on column public.http_request_logs.remark is '备注';

create index http_request_logs__index
    on public.http_request_logs (created_at, user_id);

create index http_request_logs_biz_no_biz_type_index
    on public.http_request_logs (biz_no, biz_type);

create index http_request_logs_user_id_biz_type_index
    on public.http_request_logs (user_id, biz_type);
