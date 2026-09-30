--
-- 消息表结构覆盖测试
-- 先执行建表脚本,再运行本文件;用例全部通过时逐条输出 PASS,任一失败即中断
-- 首尾清空两表,结束后不留测试数据
--
delete from public.outbox;
delete from public.inbox;

--
-- 用例:新消息默认待投递,重试计数从零开始
--
insert into public.outbox (id, aggregate_id, aggregate_type, event_type, topic, payload)
values (1001, 'O-2001', 'Order', 'OrderCreated', 'order-events', '{"orderId":"O-2001"}');

do $$
declare
    v_status text;
    v_retry  integer;
begin
    select status, retry_count into v_status, v_retry from public.outbox where id = 1001;
    if v_status is distinct from 'PENDING' or v_retry is distinct from 0 then
        raise exception '新消息默认值不符: % / %', v_status, v_retry;
    end if;
    raise notice 'PASS 新消息默认待投递且重试计数为零';
end $$;

--
-- 用例:重复投递的消息被组合唯一键拦截
--
insert into public.inbox (aggregate_id, aggregate_type, event_type, message_id, topic, payload)
values ('O-2001', 'Order', 'OrderCreated', 1001, 'order-events', '{"orderId":"O-2001"}');

do $$
begin
    begin
        insert into public.inbox (aggregate_id, aggregate_type, event_type, message_id, topic, payload)
        values ('O-2001', 'Order', 'OrderCreated', 1001, 'order-events', '{}');
        raise exception '重复消息未被拦截';
    exception when unique_violation then
        raise notice 'PASS 重复投递的消息被唯一键拦截';
    end;
end $$;

--
-- 用例:同一消息ID下不同事件类型互不影响(组合唯一而非单列唯一)
--
insert into public.inbox (aggregate_id, aggregate_type, event_type, message_id, topic, payload)
values ('O-2001', 'Order', 'OrderRefunded', 1001, 'order-events', '{"orderId":"O-2001"}');

do $$ begin raise notice 'PASS 同一消息ID下不同事件类型互不影响'; end $$;

--
-- 用例:收件箱主键由数据库自动生成
--
do $$
declare
    v_prev bigint;
    v_next bigint;
begin
    select max(id) into v_prev from public.inbox;
    insert into public.inbox (aggregate_id, aggregate_type, event_type, message_id, topic, payload)
    values ('O-2002', 'Order', 'OrderCreated', 1002, 'order-events', '{}')
    returning id into v_next;
    if v_next <= v_prev then
        raise exception '主键未自动递增: % -> %', v_prev, v_next;
    end if;
    raise notice 'PASS 收件箱主键由数据库自动生成';
end $$;

--
-- 用例:轮询索引只覆盖待投递与待重试记录
--
do $$
declare
    v_outbox_def text;
    v_inbox_def  text;
begin
    select pg_get_indexdef('public.outbox_pending_idx'::regclass) into v_outbox_def;
    if v_outbox_def not like '%created_at%'
       or position('PENDING' in v_outbox_def) = 0
       or position('FAILED' in v_outbox_def) = 0
       or position('SENT' in v_outbox_def) > 0 then
        raise exception '发件箱轮询索引定义不符: %', v_outbox_def;
    end if;

    select pg_get_indexdef('public.inbox_pending_idx'::regclass) into v_inbox_def;
    if v_inbox_def not like '%received_at%'
       or position('PENDING' in v_inbox_def) = 0
       or position('FAILED' in v_inbox_def) = 0
       or position('SUCCESS' in v_inbox_def) > 0 then
        raise exception '收件箱轮询索引定义不符: %', v_inbox_def;
    end if;
    raise notice 'PASS 轮询索引只覆盖待投递与待重试记录';
end $$;

--
-- 用例:按业务单据与消息ID的排查查询有索引支撑
--
do $$
begin
    if to_regclass('public.outbox_aggregate_id_idx') is null
       or to_regclass('public.inbox_aggregate_id_idx') is null
       or to_regclass('public.inbox_message_id_idx') is null then
        raise exception '排查索引缺失';
    end if;
    raise notice 'PASS 按业务单据与消息ID的排查查询有索引支撑';
end $$;

--
-- 用例:退避未到期的记录不会被轮询取出
-- 准备三条:可立即投递、失败未到重试时间、已投递
--
insert into public.outbox (id, aggregate_id, aggregate_type, event_type, topic, payload, status, next_retry_at)
values (3001, 'O-3001', 'Order', 'OrderPaid',      'order-events', '{}', 'PENDING', null),
       (3002, 'O-3002', 'Order', 'OrderCancelled', 'order-events', '{}', 'FAILED',  now() + interval '5 minutes'),
       (3003, 'O-3003', 'Order', 'OrderShipped',   'order-events', '{}', 'SENT',    null);

do $$
declare
    v_cnt integer;
begin
    select count(*) into v_cnt from public.outbox
    where status in ('PENDING', 'FAILED')
      and (next_retry_at is null or next_retry_at <= now());
    -- 可取:默认那条待投递 + 3001;3002 未到重试时间,3003 已投递
    if v_cnt is distinct from 2 then
        raise exception '可取记录数不符,期望 2 实际 %', v_cnt;
    end if;

    -- 重试时间到期后进入可取集合
    update public.outbox set next_retry_at = now() - interval '1 second' where id = 3002;
    select count(*) into v_cnt from public.outbox
    where status in ('PENDING', 'FAILED')
      and (next_retry_at is null or next_retry_at <= now());
    if v_cnt is distinct from 3 then
        raise exception '到期记录未进入可取集合,期望 3 实际 %', v_cnt;
    end if;
    raise notice 'PASS 退避未到期的记录不会被轮询取出';
end $$;

--
-- 用例:并发取数跳过已被占用的记录,互不阻塞
-- 两条最早的消息,第一条被当前语句占用,第二连接应立即取到第二条
--
insert into public.outbox (id, aggregate_id, aggregate_type, event_type, topic, payload, created_at)
values (4001, 'O-4001', 'Order', 'OrderPaid', 'order-events', '{}', now() - interval '1 hour'),
       (4002, 'O-4002', 'Order', 'OrderPaid', 'order-events', '{}', now() - interval '1 hour');

create extension if not exists dblink;

do $$
declare
    v_id bigint;
begin
    perform 1 from public.outbox where id = 4001 for update;
    select t.id into v_id from dblink(
            'dbname=messaging_db user=admin',
            'select id from public.outbox '
            'where status in (''PENDING'', ''FAILED'') '
            'and (next_retry_at is null or next_retry_at <= now()) '
            'order by created_at limit 1 for update skip locked')
        as t(id bigint);
    if v_id is distinct from 4002 then
        raise exception '并发取数未跳过已占用记录,实际取到: %', v_id;
    end if;
    raise notice 'PASS 并发取数跳过已被占用的记录,互不阻塞';
end $$;

--
-- 收尾:清理测试数据
--
delete from public.outbox;
delete from public.inbox;
