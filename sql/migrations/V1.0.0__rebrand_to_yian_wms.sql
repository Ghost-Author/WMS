-- Existing-database migration for the 1.0.0 naming update.
-- The statements are idempotent and target only built-in seed records.

START TRANSACTION;

DELETE FROM sys_role_menu WHERE menu_id = 4;
DELETE FROM sys_menu WHERE menu_id = 4;

UPDATE sys_dept
SET dept_name = CASE dept_id
        WHEN 100 THEN '以安仓储'
        WHEN 101 THEN '总部'
        WHEN 102 THEN '运营中心'
        WHEN 103 THEN '研发部门'
        WHEN 104 THEN '市场部门'
        WHEN 105 THEN '测试部门'
        WHEN 106 THEN '财务部门'
        WHEN 107 THEN '运维部门'
        WHEN 108 THEN '运营部门'
        WHEN 109 THEN '客服部门'
    END,
    leader = '管理员',
    email = 'contact@yian.local',
    update_by = 'admin',
    update_time = NOW()
WHERE dept_id BETWEEN 100 AND 109;

UPDATE sys_user
SET nick_name = '管理员',
    email = 'admin@yian.local',
    update_by = 'admin',
    update_time = NOW()
WHERE user_id = 1;

UPDATE sys_user
SET user_name = 'tester',
    nick_name = '测试员',
    email = 'tester@yian.local',
    update_by = 'admin',
    update_time = NOW()
WHERE user_id = 2;

UPDATE sys_job
SET invoke_target = CASE job_id
        WHEN 1 THEN 'sampleTask.withoutParams'
        WHEN 2 THEN 'sampleTask.withParams(\'sample\')'
        WHEN 3 THEN 'sampleTask.multipleParams(\'sample\', true, 2000L, 316.50D, 100)'
    END,
    update_by = 'admin',
    update_time = NOW()
WHERE job_id IN (1, 2, 3);

DELETE FROM sys_notice_read WHERE notice_id IN (1, 2, 3);

UPDATE sys_notice
SET notice_title = '欢迎使用以安WMS',
    notice_type = '2',
    notice_content = '<p>以安WMS 测试环境已就绪，请使用左侧菜单进入仓储业务模块。</p>',
    update_by = 'admin',
    update_time = NOW(),
    remark = '管理员'
WHERE notice_id = 1;

UPDATE sys_notice
SET notice_title = '测试环境安全提示',
    notice_type = '1',
    notice_content = '<p>首次登录后请修改默认密码，并妥善保管系统账号。</p>',
    update_by = 'admin',
    update_time = NOW(),
    remark = '管理员'
WHERE notice_id = 2;

UPDATE sys_notice
SET notice_title = '仓储业务使用提示',
    notice_type = '1',
    notice_content = '<p>请先维护仓库、库区、库位和物料，再创建入库单或出库单。</p>',
    update_by = 'admin',
    update_time = NOW(),
    remark = '管理员'
WHERE notice_id = 3;

COMMIT;
