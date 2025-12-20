local SyncValidator = {}

function SyncValidator.IsValid(payload)
	return typeof(payload) == "table"
end

return SyncValidator
