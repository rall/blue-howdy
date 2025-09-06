After do
  if @mock_tag
    Container.cleanup!(@mock_tag)
  end
end