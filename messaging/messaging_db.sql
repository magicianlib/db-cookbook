create database messaging_db;

--
-- 消息发件箱
--
drop table if exists public.outbox;
create table public.outbox
(
    id             bigint                                 not null
        constraint outbox_pk
            primary key,
    aggregate_id   varchar(500)                           not null,
    aggregate_type varchar(500)                           not null,
    event_type     varchar(500)                           not null,
    message_key    varchar(500)                           not null,
    payload        jsonb                                  not null,
    headers        jsonb,
    status         varchar(100)                           not null,
    created_at     timestamp with time zone default now() not null,
    updated_at     timestamp with time zone default now() not null,
    send_at        timestamp with time zone,
    retry_count    integer                  default 0     not null,
    last_error     text,
    remark         text
);

comment on table public.outbox is '消息发件箱';

comment on column public.outbox.id is '消息ID';

comment on column public.outbox.aggregate_id is '聚合根ID';

comment on column public.outbox.aggregate_type is '聚合类型';

comment on column public.outbox.event_type is '事件类型';

comment on column public.outbox.message_key is '消息路由key';

comment on column public.outbox.payload is '消息体';

comment on column public.outbox.headers is '消息头';

comment on column public.outbox.status is '投递状态(PENDING:待处理, SENT:已投递, FAILED:投递失败)';

comment on column public.outbox.created_at is '消息创建时间';

comment on column public.outbox.updated_at is '最后更新时间';

comment on column public.outbox.send_at is '消息成功投递时间';

comment on column public.outbox.retry_count is '重试次数';

comment on column public.outbox.last_error is '最近一次失败原因';

comment on column public.outbox.remark is '备注说明';

--
-- 消息收件箱
--
drop table if exists public.inbox;
create table public.inbox
(
    id             bigint                                 not null
        constraint inbox_pk
            primary key,
    aggregate_id   varchar(500)                           not null,
    aggregate_type varchar(500)                           not null,
    event_type     varchar(500)                           not null,
    message_id     bigint                                 not null,
    message_key    varchar(500)                           not null,
    payload        jsonb                                  not null,
    received_at    timestamp with time zone default now() not null,
    status         varchar(100)                           not null,
    processed_at   timestamp with time zone,
    remark         text
);

comment on table public.inbox is '消息收件箱';

comment on column public.inbox.id is '主键ID';

comment on column public.inbox.aggregate_id is '聚合根ID';

comment on column public.inbox.aggregate_type is '聚合类型';

comment on column public.inbox.event_type is '事件类型';

comment on column public.inbox.message_id is '消息ID';

comment on column public.inbox.message_key is '消息路由key';

comment on column public.inbox.payload is '消息内容';

comment on column public.inbox.received_at is '消息接收时间';

comment on column public.inbox.status is '消息(PENDING:待处理, PROCESSING:处理中, SUCCESS:处理成功, FAILED:处理失败)';

comment on column public.inbox.processed_at is '处理完成时间';

comment on column public.inbox.remark is '备注说明';

create unique index inbox_event_type_message_id_uindex
    on public.inbox (event_type, message_id);