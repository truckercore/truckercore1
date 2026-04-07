begin;

create or replace view iam_group_drift_detail as
select
  ou.org_id, ou.user_id,
  ou.role as app_role,
  coalesce(jsonb_agg(sg.group_display)
           filter (where sg.group_display is not null), '[]'::jsonb) as idp_groups
from org_users ou
left join scim_group_memberships sgm
  on sgm.org_id=ou.org_id and sgm.user_id=ou.user_id
left join scim_groups sg
  on sg.org_id=sgm.org_id and sg.group_id=sgm.group_id
group by 1,2,3
having (ou.role = 'admin' and not exists (
          select 1 from scim_group_mappings m
          where m.org_id=ou.org_id and m.app_role='admin'
            and m.idp_group = any(array(select sg2.group_display
                                         from scim_groups sg2
                                         where sg2.org_id=ou.org_id))
       ))
    or (ou.role = 'manager' and not exists (
          select 1 from scim_group_mappings m
          where m.org_id=ou.org_id and m.app_role='manager'
            and m.idp_group = any(array(select sg2.group_display
                                         from scim_groups sg2
                                         where sg2.org_id=ou.org_id))
       ));

commit;
