-- create database messaging_db;

--
-- 消息发件箱
--
drop table if exists public.outbox;
create table public.outbox
(
    message_id     bigint                                     not null
        constraint outbox_pk
            primary key,
    aggregate_type text                                       not null,
    aggregate_id   text                                       not null,
    event_type     text                                       not null,
    payload        jsonb                                      not null,
    status         text                     default 'PENDING' not null,
    created_at     timestamp with time zone default now()     not null,
    updated_at     timestamp with time zone default now()     not null,
    sent_at        timestamp with time zone,
    retry_count    integer                  default 0         not null,
    last_error     text,
    next_retry_at  timestamp with time zone,
    version        integer                  default 0         not null,
    remark         text
);

comment on table public.outbox is '消息发件箱';

comment on column public.outbox.message_id is '消息ID,应保证全局唯一便于下游消息去重';

comment on column public.outbox.aggregate_type is 'topic';

comment on column public.outbox.aggregate_id is '消息路由key';

comment on column public.outbox.event_type is 'topic具体业务类型';

comment on column public.outbox.payload is '消息体';

comment on column public.outbox.status is '投递状态(PENDING:待投递, SENT:已投递, FAILED:投递失败, DEAD:重试超限转死信)';

comment on column public.outbox.created_at is '消息创建时间';

comment on column public.outbox.updated_at is '最后更新时间';

comment on column public.outbox.sent_at is '消息成功投递时间';

comment on column public.outbox.retry_count is '重试次数';

comment on column public.outbox.last_error is '最近一次失败原因';

comment on column public.outbox.next_retry_at is '下次允许重试时间,为空表示可立即重试';

comment on column public.outbox.version is '版本';

comment on column public.outbox.remark is '备注说明';


--
-- 消息收件箱
--
drop table if exists public.inbox;
create table public.inbox
(
    id             bigint generated always as identity
        constraint inbox_pk
            primary key,
    message_id     bigint                                     not null,
    aggregate_type text                                       not null,
    aggregate_id   text                                       not null,
    event_type     text                                       not null,
    payload        jsonb                                      not null,
    status         text                     default 'PENDING' not null,
    received_at    timestamp with time zone default now()     not null,
    processed_at   timestamp with time zone,
    retry_count    integer                  default 0         not null,
    last_error     text,
    next_retry_at  timestamp with time zone,
    remark         text
);

comment on table public.inbox is '消息收件箱';

comment on column public.inbox.id is '主键ID';

comment on column public.inbox.message_id is '消息ID';

comment on column public.outbox.aggregate_type is 'topic';

comment on column public.outbox.aggregate_id is '消息路由key';

comment on column public.outbox.event_type is 'topic具体业务类型';

comment on column public.inbox.payload is '消息内容';

comment on column public.inbox.status is '处理状态(PENDING:待处理, PROCESSING:处理中, SUCCESS:处理成功, FAILED:处理失败, DEAD:重试超限转死信)';

comment on column public.inbox.received_at is '消息接收时间';

comment on column public.inbox.processed_at is '处理完成时间';

comment on column public.inbox.retry_count is '重试次数';

comment on column public.inbox.last_error is '最近一次失败原因';

comment on column public.inbox.next_retry_at is '下次允许重试时间,为空表示可立即重试';

comment on column public.inbox.remark is '备注说明';

create unique index inbox_message_id_uindex
    on public.inbox (message_id);
