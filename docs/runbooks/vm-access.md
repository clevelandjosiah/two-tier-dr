# VM access

Normal access is Entra ID through Bastion. The SSH key in ~/.ssh/two-tier-dr is break-glass only.

1. Set deploy_bastion = true in the stack and apply.
2. Install the CLI extensions once:

   az extension add --name bastion
   az extension add --name ssh

3. Connect:

   az network bastion ssh --name bas-dr-eus2 --resource-group rg-dr-eus2 \
     --target-resource-id <vm id from terraform output vm_ids> --auth-type AAD

After a failover, use bas-dr-cus and rg-dr-cus. If Entra login fails on a
failed-over VM, re-enable its managed identity or use the break-glass key.
