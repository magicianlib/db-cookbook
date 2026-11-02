-- 资金库
-- create database fund_db;

--
-- 资金账户
--
drop table if exists public.fund_account;
create table public.fund_account
(
    account_id        uuid           default uuidv7() not null
        constraint fund_account_pk
            primary key,
    account_no        text                            not null,
    account_status    text                            not null,
    account_type      text                            not null,
    owner_id          text                            not null,
    owner_type        text                            not null,
    currency          text                            not null,
    total_balance     numeric(20, 6) default 0        not null,
    available_balance numeric(20, 6) default 0        not null,
    frozen_balance    numeric(20, 6) default 0        not null,
    pending_amount    numeric(20, 6) default 0        not null,
    version           bigint         default 0        not null,
    remark            text,
    opened_at         timestamptz                     not null,
    last_settled_at   timestamptz,
    created_at        timestamptz    default now()    not null,
    updated_at        timestamptz                     not null
);

comment on table public.fund_account is '资金账户表';

comment on column public.fund_account.account_id is '账户ID';

comment on column public.fund_account.account_no is '账户业务编号(对外展示)';

comment on column public.fund_account.account_status is '账户状态';

comment on column public.fund_account.account_type is '账户类型(CASH:现金/可用余额账户, DEPOSIT:保证金/押金账户, SETTLEMENT:待结算/结算账户, FEE:手续费账户)';

comment on column public.fund_account.owner_id is '账户主体ID(用户/商户/渠道)';

comment on column public.fund_account.owner_type is '主体类型(USER:用户, MERCHANT:商户, CHANNEL:渠道, PLATFORM:平台)';

comment on column public.fund_account.currency is '账户币种(ISO 4217)';

comment on column public.fund_account.total_balance is '总余额 = 可用 + 冻结 + 在途';

comment on column public.fund_account.available_balance is '可用余额';

comment on column public.fund_account.frozen_balance is '冻结余额';

comment on column public.fund_account.pending_amount is '在途金额(结算中未到账)';

comment on column public.fund_account.version is '乐观锁版本号';

comment on column public.fund_account.remark is '备注';

comment on column public.fund_account.opened_at is '开户时间';

comment on column public.fund_account.last_settled_at is '最近结算时间';

comment on column public.fund_account.created_at is '创建时间';

comment on column public.fund_account.updated_at is '更新时间';

create unique index fund_account_account_no_uindex
    on public.fund_account (account_no);

create unique index fund_account_owner_id_currency_uindex
    on public.fund_account (owner_id, currency);


--
-- 资金流水
--
drop table if exists public.fund_transaction;
create table public.fund_transaction
(
    transaction_id uuid        default uuidv7() not null
        constraint fund_transaction_pk
            primary key,
    transaction_no text                         not null,
    account_id     uuid                         not null,
    account_no     text                         not null,
    biz_type       text                         not null,
    biz_no         text                         not null,
    balance_type   text                         not null,
    direction      text                         not null,
    balance_before numeric(20, 6)               not null,
    amount         numeric(20, 6)               not null,
    balance_after  numeric(20, 6)               not null,
    currency       text                         not null,
    settle_status  text                         not null,
    settled_at     timestamptz,
    remark         text,
    created_at     timestamptz default now()    not null,
    updated_at     timestamptz                  not null
);

comment on table public.fund_transaction is '资金流水表';

comment on column public.fund_transaction.transaction_id is '流水ID';

comment on column public.fund_transaction.transaction_no is '流水业务编号(全局唯一)';

comment on column public.fund_transaction.account_id is '账户ID';

comment on column public.fund_transaction.account_no is '账户编号';

comment on column public.fund_transaction.biz_type is '业务类型';

comment on column public.fund_transaction.biz_no is '业务单号';

comment on column public.fund_transaction.balance_type is '余额类型(AVAILABLE:可用余额, FROZEN:冻结余额, PENDING:在途余额';

comment on column public.fund_transaction.direction is '收支方向：IN/OUT';

comment on column public.fund_transaction.balance_before is '交易前余额';

comment on column public.fund_transaction.amount is '发生金额';

comment on column public.fund_transaction.balance_after is '交易后余额';

comment on column public.fund_transaction.currency is '币种(ISO 4217)';

comment on column public.fund_transaction.settle_status is '结算状态';

comment on column public.fund_transaction.settled_at is '结算时间';

comment on column public.fund_transaction.remark is '备注';

comment on column public.fund_transaction.created_at is '创建时间';

comment on column public.fund_transaction.updated_at is '更新时间';

create index fund_transaction_account_id__index
    on public.fund_transaction (account_id, created_at);

create index fund_transaction_biz_no_index
    on public.fund_transaction (biz_no);

create unique index fund_transaction_biz_type_biz_no_account_id_uindex
    on public.fund_transaction (biz_type, biz_no, account_id);

create unique index fund_transaction_transaction_no_uindex
    on public.fund_transaction (transaction_no);
