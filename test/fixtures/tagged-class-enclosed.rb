#tag::all[]
class Dog
  #tag::init[]
  def initialize breed
    @breed = breed
  end
  #end::init[]
  #tag::bark[]

  def bark
    #tag::bark-beagle[]
    if @breed == 'beagle'
      'woof woof woof woof woof'
    #end::bark-beagle[]
    #tag::bark-other[]
    else
      'woof woof'
    #end::bark-other[]
    #tag::bark-all[]
    end
    #end::bark-all[]
  end
  #end::bark[]
end
#end::all[]
