create database messaging_db;

--
-- 消息发件箱
--
drop table if exists public.outbox;
create table public.outbox
(
    id             bigint                                  not null
        constraint outbox_pk
            primary key,
    aggregate_id   text                                    not null,
    aggregate_type text                                    not null,
    event_type     text                                    not null,
    topic          text                                    not null,
    payload        jsonb                                   not null,
    headers        jsonb,
    status         text             default 'PENDING'       not null,
    created_at     timestamp with time zone default now()  not null,
    updated_at     timestamp with time zone default now()  not null,
    send_at        timestamp with time zone,
    retry_count    integer          default 0              not null,
    last_error     text,
    next_retry_at  timestamp with time zone,
    remark         text
);

comment on table public.outbox is '消息发件箱';

comment on column public.outbox.id is '消息ID,应用侧生成(如雪花ID),需在同一事务内确定以便传给下游去重';

comment on column public.outbox.aggregate_id is '聚合根ID,消息按此分区,保证同一聚合内有序';

comment on column public.outbox.aggregate_type is '聚合类型';

comment on column public.outbox.event_type is '事件类型';

comment on column public.outbox.topic is '发布目标主题';

comment on column public.outbox.payload is '消息体';

comment on column public.outbox.headers is '消息头';

comment on column public.outbox.status is '投递状态(PENDING:待投递, SENT:已投递, FAILED:投递失败, DEAD:重试超限转死信)';

comment on column public.outbox.created_at is '消息创建时间';

comment on column public.outbox.updated_at is '最后更新时间';

comment on column public.outbox.send_at is '消息成功投递时间';

comment on column public.outbox.retry_count is '重试次数';

comment on column public.outbox.last_error is '最近一次失败原因';

comment on column public.outbox.next_retry_at is '下次允许重试时间,为空表示可立即重试';

comment on column public.outbox.remark is '备注说明';

-- 待投递与待重试记录占比极小,只索引这一部分,轮询不必扫描已投递记录
create index outbox_pending_idx
    on public.outbox (created_at)
    where status in ('PENDING', 'FAILED');

-- 支持按业务单据追溯其发出的全部消息
create index outbox_aggregate_id_idx
    on public.outbox (aggregate_id);

--
-- 消息收件箱
--
drop table if exists public.inbox;
create table public.inbox
(
    id             bigint generated always as identity
        constraint inbox_pk
            primary key,
    aggregate_id   text                                    not null,
    aggregate_type text                                    not null,
    event_type     text                                    not null,
    message_id     bigint                                  not null,
    topic          text                                    not null,
    payload        jsonb                                   not null,
    status         text             default 'PENDING'       not null,
    received_at    timestamp with time zone default now()  not null,
    processed_at   timestamp with time zone,
    retry_count    integer          default 0              not null,
    last_error     text,
    next_retry_at  timestamp with time zone,
    remark         text,
    constraint inbox_event_type_message_id_uidx
        unique (event_type, message_id)
);

comment on table public.inbox is '消息收件箱';

comment on column public.inbox.id is '主键ID';

comment on column public.inbox.aggregate_id is '聚合根ID,同一聚合的消息需串行处理';

comment on column public.inbox.aggregate_type is '聚合类型';

comment on column public.inbox.event_type is '事件类型';

comment on column public.inbox.message_id is '消息ID,取自发件箱记录主键';

comment on column public.inbox.topic is '消息来源主题';

comment on column public.inbox.payload is '消息内容';

comment on column public.inbox.status is '处理状态(PENDING:待处理, PROCESSING:处理中, SUCCESS:处理成功, FAILED:处理失败, DEAD:重试超限转死信)';

comment on column public.inbox.received_at is '消息接收时间';

comment on column public.inbox.processed_at is '处理完成时间';

comment on column public.inbox.retry_count is '重试次数';

comment on column public.inbox.last_error is '最近一次失败原因';

comment on column public.inbox.next_retry_at is '下次允许重试时间,为空表示可立即重试';

comment on column public.inbox.remark is '备注说明';

-- 待处理与待重试记录占比极小,只索引这一部分,处理线程轮询不必扫描已处理记录
create index inbox_pending_idx
    on public.inbox (received_at)
    where status in ('PENDING', 'FAILED');

-- 支持按业务单据追溯其收到的全部消息
create index inbox_aggregate_id_idx
    on public.inbox (aggregate_id);

-- 支持从发件箱记录直接跳查收件箱的处理结果
create index inbox_message_id_idx
    on public.inbox (message_id);
